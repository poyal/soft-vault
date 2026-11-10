import 'library_filter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'catalog_schema.dart';
part 'catalog_scan.dart';

class Library {
  final Database db;
  Library._(this.db);
  Future<void> _fileTail = Future.value();

  /// Serialize catalog filesystem mutations across scanners and job instances.
  Future<T> fileOperation<T>(Future<T> Function() action) {
    final next = _fileTail.then((_) => action());
    _fileTail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  static Future<Library> open(String path) async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onOpen: (db) async {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS media_fingerprint ON media(fingerprint)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS media_folder ON media(folder)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS media_recent ON media(added DESC,id DESC)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS actor_media ON media_actors(actor_id,media_id)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS tag_media ON media_tags(tag_id,media_id)',
          );
        },
        onUpgrade: (db, old, version) async {
          if (old < 2) await upgradeCatalog(db);
          if (old < 3) await upgradeFeatures(db);
          if (old < 4) await upgradePlaybackHistory(db);
        },
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE folders (path TEXT PRIMARY KEY)');
          await db.execute('''CREATE TABLE media (
          id INTEGER PRIMARY KEY, path TEXT UNIQUE NOT NULL,
          folder TEXT NOT NULL, title TEXT NOT NULL, type TEXT NOT NULL,
          rating INTEGER CHECK(rating BETWEEN 1 AND 5),
          description TEXT NOT NULL DEFAULT '', actors TEXT NOT NULL DEFAULT '',
          tags TEXT NOT NULL DEFAULT '', added INTEGER NOT NULL)''');
          await upgradeCatalog(db);
          await upgradeFeatures(db);
          await upgradePlaybackHistory(db);
        },
      ),
    );
    return Library._(db);
  }

  Future<List<String>> folders() async =>
      (await db.query('folders')).map((row) => row['path'] as String).toList();

  /// Interactive folder browsing uses verifyContents:false. Deep verification
  /// remains available for import/reconciliation tools that need exact hashes.
  Future<void> connect(String path, {bool verifyContents = true}) =>
      fileOperation(() async {
        final root = await Directory(path).resolveSymbolicLinks();
        await db.insert('folders', {
          'path': root,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await _scan(root, verifyContents: verifyContents);
      });

  /// Resolve existing ancestors too, so an offline /var path still matches
  /// the /private/var path stored while the directory was connected on macOS.
  static Future<String> canonicalPath(String path) async {
    var current = p.normalize(p.absolute(path));
    final missing = <String>[];
    while (true) {
      try {
        final resolved = await Directory(current).resolveSymbolicLinks();
        return p.joinAll([resolved, ...missing.reversed]);
      } on FileSystemException {
        final parent = p.dirname(current);
        if (parent == current) return p.normalize(p.absolute(path));
        missing.add(p.basename(current));
        current = parent;
      }
    }
  }

  Future<void> scan(String root, {bool verifyContents = true}) => fileOperation(
    () async =>
        _scan(await canonicalPath(root), verifyContents: verifyContents),
  );

  static Future<String> fingerprint(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<List<Map<String, Object?>>> items({
    String query = '',
    String? folder,
    String? type,
    int? minimumRating,
    bool unrated = false,
    String sort = 'recent',
    int? limit,
    List<LibraryFilter> filters = const [],
  }) async => db.query(
    'media',
    where:
        '''type = 'video' AND (title LIKE ? ESCAPE '!' OR path LIKE ? ESCAPE '!' OR description LIKE ? ESCAPE '!'
      OR actors LIKE ? ESCAPE '!' OR tags LIKE ? ESCAPE '!' OR note LIKE ? ESCAPE '!' OR id IN
      (SELECT media_id FROM media_actors JOIN actors ON actors.id = actor_id WHERE alias LIKE ? ESCAPE '!'))
      ${folder == null ? '' : ' AND folder = ?'}${type == null ? '' : ' AND type = ?'}
      ${minimumRating == null ? '' : ' AND rating >= ?'}${unrated ? ' AND rating IS NULL' : ''}
      ${[for (final filter in filters) ...filter.clauses].map((clause) => ' AND ($clause)').join()}''',
    whereArgs: [
      ...List.filled(
        7,
        '%${query.replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_')}%',
      ),
      if (folder != null) await canonicalPath(folder),
      if (type != null) type,
      if (minimumRating != null) minimumRating,
      for (final filter in filters) ...filter.arguments,
    ],
    orderBy:
        {
          'recent': 'added DESC, id DESC',
          'name': 'title COLLATE NOCASE, id',
          'rating': 'rating DESC, id',
          'duration': 'duration DESC, id',
        }[sort] ??
        'added DESC, id DESC',
    limit: limit,
  );
  Future<void> edit(int id, Map<String, Object?> values) async {
    const allowed = {
      'title',
      'description',
      'note',
      'actors',
      'tags',
      'rating',
    };
    if (!values.keys.every(allowed.contains))
      throw ArgumentError('Invalid metadata field');
    await db.transaction((tx) async {
      await tx.update('media', values, where: 'id = ?', whereArgs: [id]);
      for (final kind in ['actors', 'tags']) {
        if (values.containsKey(kind))
          await setRelations(tx, id, kind, values[kind] as String);
      }
    });
  }

  Future<void> batchEdit(
    Iterable<int> ids, {
    int? rating,
    bool setRating = false,
    String tags = '',
    bool removeTags = false,
  }) async {
    await db.transaction((tx) async {
      for (final id in ids.toSet()) {
        final item = (await tx.query(
          'media',
          where: 'id = ?',
          whereArgs: [id],
        )).single;
        final updated = names(item['tags'] as String).toSet();
        if (removeTags) {
          updated.removeAll(names(tags));
        } else {
          updated.addAll(names(tags));
        }
        final values = <String, Object?>{
          if (setRating) 'rating': rating,
          'tags': updated.join(', '),
        };
        await tx.update('media', values, where: 'id=?', whereArgs: [id]);
        if (item['tags'] != values['tags'])
          await setRelations(tx, id, 'tags', values['tags'] as String);
      }
    });
  }

  Future<List<Map<String, Object?>>> entities(String kind) {
    if (!['actors', 'tags'].contains(kind)) throw ArgumentError('Invalid kind');
    final field = kind == 'actors' ? 'actor_id' : 'tag_id';
    return db.rawQuery(
      "SELECT e.*, (SELECT count(*) FROM media_$kind r JOIN media m ON m.id=r.media_id WHERE r.$field=e.id AND m.type='video') AS count FROM $kind e ORDER BY name",
    );
  }

  Future<void> saveActor({
    int? id,
    required String name,
    String alias = '',
    String image = '',
    String description = '',
  }) async {
    if (name.trim().isEmpty || name.contains(','))
      throw ArgumentError('배우 이름을 확인하세요.');
    final values = {
      'name': name.trim(),
      'alias': alias,
      'image': image,
      'description': description,
    };
    if (id == null) {
      await db.insert('actors', values);
    } else {
      final old = (await db.query(
        'actors',
        where: 'id = ?',
        whereArgs: [id],
      )).single['name'];
      await db.update('actors', values, where: 'id = ?', whereArgs: [id]);
      for (final item in await db.query('media')) {
        final values = names(item['actors'] as String);
        if (values.contains(old))
          await edit(item['id'] as int, {
            'actors': values
                .map((value) => value == old ? name.trim() : value)
                .join(', '),
          });
      }
    }
  }

  Future<void> renameTag(String old, String next) async {
    if (next.trim().isEmpty || next.contains(','))
      throw ArgumentError('태그 이름을 확인하세요.');
    await db.insert('tags', {
      'name': next.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    for (final item in await db.query('media')) {
      final tags = names(item['tags'] as String);
      if (tags.contains(old))
        await edit(item['id'] as int, {
          'tags': tags
              .map((tag) => tag == old ? next.trim() : tag)
              .toSet()
              .join(', '),
        });
    }
    if (old != next.trim())
      await db.delete('tags', where: 'name = ?', whereArgs: [old]);
  }

  Future<void> setting(String key, Object value) => db
      .insert('settings', {
        'key': key,
        'value': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<Object?> readSetting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : jsonDecode(rows.single['value'] as String);
  }

  Future<void> exportTo(File target) async {
    final data = <String, Object?>{'version': 4};
    await db.transaction((tx) async {
      for (final table in [
        'folders',
        'media',
        'actors',
        'tags',
        'media_actors',
        'media_tags',
        'settings',
        'bookmarks',
        'collections',
        'move_rules',
        'playback_history',
      ]) {
        data[table] = await tx.query(table);
      }
    });
    await target.writeAsString(jsonEncode(data), flush: true);
  }

  Future<void> restoreFrom(File source) async {
    final data =
        jsonDecode(await source.readAsString()) as Map<String, dynamic>;
    if (![2, 3, 4].contains(data['version']))
      throw FormatException('지원하지 않는 백업 버전');
    if (data['version'] != 4) data['playback_history'] = [];
    if (data['version'] == 2) {
      for (final table in ['bookmarks', 'collections', 'move_rules']) {
        data[table] = [];
      }
    }
    const tables = [
      'folders',
      'media',
      'actors',
      'tags',
      'media_actors',
      'media_tags',
      'settings',
      'bookmarks',
      'collections',
      'move_rules',
      'playback_history',
    ];
    for (final table in tables) {
      if (data[table] is! List) throw FormatException('잘못된 백업: $table');
      for (final row in data[table] as List) {
        if (row is! Map ||
            row.keys.any((key) => key is! String) ||
            row.values.any(
              (value) => value != null && value is! num && value is! String,
            )) {
          throw FormatException('잘못된 백업 행: $table');
        }
      }
    }
    // Validate references before replacing any table; older schemas lack FKs.
    final mediaIds = (data['media'] as List).map((row) => row['id']).toSet();
    final actorIds = (data['actors'] as List).map((row) => row['id']).toSet();
    final tagIds = (data['tags'] as List).map((row) => row['id']).toSet();
    for (final table in [
      'bookmarks',
      'media_actors',
      'media_tags',
      'playback_history',
    ]) {
      for (final row in data[table] as List) {
        if (!mediaIds.contains(row['media_id']) ||
            (table == 'media_actors' && !actorIds.contains(row['actor_id'])) ||
            (table == 'media_tags' && !tagIds.contains(row['tag_id'])))
          throw FormatException('잘못된 백업 참조: $table');
      }
    }
    // Preserve the existing catalog if any row fails validation/constraints.
    await fileOperation(
      () => db.transaction((tx) async {
        await tx.delete('jobs');
        for (final table in tables.reversed) {
          await tx.delete(table);
        }
        for (final table in tables) {
          for (final row in data[table] as List) {
            await tx.insert(table, Map<String, Object?>.from(row as Map));
          }
        }
      }),
    );
  }

  Future<void> close() => db.close();

  Future<void> disconnect(String root) => fileOperation(() async {
    root = await canonicalPath(root);
    await db.transaction((tx) async {
      await tx.delete('folders', where: 'path = ?', whereArgs: [root]);
      await tx.update(
        'media',
        {'online': 0},
        where: 'folder = ?',
        whereArgs: [root],
      );
    });
  });

  Future<void> relink(
    int id,
    String next, {
    bool replaceIndexEntry = false,
  }) async {
    final item = (await db.query(
      'media',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    final file = File(await File(next).resolveSymbolicLinks());
    final digest = await fingerprint(file);
    if (item['fingerprint'] != '' && item['fingerprint'] != digest)
      throw StateError('선택한 파일의 내용이 원본 지문과 다릅니다.');
    final roots =
        (await folders()).where((root) => p.isWithin(root, file.path)).toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    final root = roots.isEmpty ? p.dirname(file.path) : roots.first;
    final duplicates = await db.query(
      'media',
      where: 'path = ? AND id != ?',
      whereArgs: [file.path, id],
    );
    if (duplicates.isNotEmpty && !replaceIndexEntry)
      throw StateError('이미 등록된 파일입니다. 기존 연결 항목의 교체 확인이 필요합니다.');
    final stat = await file.stat();
    await db.transaction((tx) async {
      for (final duplicate in duplicates) {
        await tx.delete(
          'playback_history',
          where: 'media_id = ?',
          whereArgs: [duplicate['id']],
        );
        await tx.delete(
          'bookmarks',
          where: 'media_id = ?',
          whereArgs: [duplicate['id']],
        );
        await tx.delete(
          'media_actors',
          where: 'media_id = ?',
          whereArgs: [duplicate['id']],
        );
        await tx.delete(
          'media_tags',
          where: 'media_id = ?',
          whereArgs: [duplicate['id']],
        );
        await tx.delete('media', where: 'id = ?', whereArgs: [duplicate['id']]);
      }
      await tx.insert('folders', {
        'path': root,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await tx.update(
        'media',
        {
          'path': file.path,
          'folder': root,
          'fingerprint': digest,
          'size': stat.size,
          'modified': stat.modified.millisecondsSinceEpoch,
          'online': 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
