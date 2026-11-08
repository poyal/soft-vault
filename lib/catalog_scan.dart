part of 'library.dart';

extension _CatalogScan on Library {
  Future<void> _scan(String root) async {
    if (!await Directory(root).exists()) {
      await db.update(
        'media',
        {'online': 0},
        where: 'folder=? AND online!=0',
        whereArgs: [root],
      );
      return;
    }
    String key(String path) => Platform.isWindows
        ? p.normalize(path).toLowerCase()
        : p.normalize(path);
    final roots = await folders()
      ..sort((a, b) => b.length.compareTo(a.length));
    final rows = await db.query('media');
    final existing = {for (final row in rows) key(row['path'] as String): row};
    final hashes = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      hashes.putIfAbsent(row['fingerprint'] as String, () => []).add(row);
    }
    final seen = <String>{}, claimed = <int>{};
    final missingCache = <int, bool>{};
    final writes = <void Function(Batch)>[];
    Future<void> flush() async {
      if (writes.isEmpty) return;
      await db.transaction((tx) async {
        final batch = tx.batch();
        for (final write in writes) {
          write(batch);
        }
        await batch.commit(noResult: true);
      });
      writes.clear();
    }

    await for (final entity in Directory(
      root,
    ).list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final extension = p.extension(entity.path).toLowerCase();
      const videos = {'.mp4', '.mkv', '.avi', '.mov', '.webm', '.wmv', '.ts'};
      if (!videos.contains(extension)) continue;
      final path = entity.absolute.path, pathKey = key(path);
      final owners = roots.where((folder) => p.isWithin(folder, path));
      final owner = owners.isEmpty ? root : owners.first;
      final old = existing[pathKey];
      try {
        final stat = await entity.stat();
        if (stat.type != FileSystemEntityType.file) continue;
        seen.add(pathKey);
        if (old != null &&
            old['size'] == stat.size &&
            old['modified'] == stat.modified.millisecondsSinceEpoch) {
          if (old['online'] != 1 || old['folder'] != owner) {
            writes.add(
              (batch) => batch.update(
                'media',
                {'online': 1, 'folder': owner},
                where: 'id=?',
                whereArgs: [old['id']],
              ),
            );
          }
        } else {
          final digest = await Library.fingerprint(entity);
          if (old != null) {
            final changed = old['fingerprint'] != digest;
            writes.add((batch) {
              batch.update(
                'media',
                {
                  'fingerprint': digest,
                  'size': stat.size,
                  'modified': stat.modified.millisecondsSinceEpoch,
                  'folder': owner,
                  'online': 1,
                  if (changed) ...{
                    'thumbnail': '',
                    'custom_thumbnail': 0,
                    'duration': 0,
                    'codec': '',
                    'resolution': '',
                    'resume_ms': 0,
                    'watched': 0,
                    'last_played': 0,
                  },
                },
                where: 'id=?',
                whereArgs: [old['id']],
              );
              if (changed)
                batch.delete(
                  'bookmarks',
                  where: 'media_id=?',
                  whereArgs: [old['id']],
                );
            });
          } else {
            final missing = <Map<String, Object?>>[];
            for (final candidate
                in hashes[digest] ?? <Map<String, Object?>>[]) {
              final id = candidate['id'] as int;
              if (claimed.contains(id)) continue;
              final absent = missingCache[id] ??=
                  await Directory(candidate['folder'] as String).exists() &&
                  !await File(candidate['path'] as String).exists();
              if (absent) missing.add(candidate);
            }
            if (missing.length == 1) {
              final id = missing.single['id'] as int;
              claimed.add(id);
              writes.add(
                (batch) => batch.update(
                  'media',
                  {
                    'path': path,
                    'folder': owner,
                    'online': 1,
                    'size': stat.size,
                    'modified': stat.modified.millisecondsSinceEpoch,
                  },
                  where: 'id=?',
                  whereArgs: [id],
                ),
              );
            } else {
              writes.add(
                (batch) => batch.insert('media', {
                  'path': path,
                  'folder': owner,
                  'title': p.basenameWithoutExtension(path),
                  'type': 'video',
                  'added': DateTime.now().millisecondsSinceEpoch,
                  'size': stat.size,
                  'modified': stat.modified.millisecondsSinceEpoch,
                  'fingerprint': digest,
                }, conflictAlgorithm: ConflictAlgorithm.ignore),
              );
            }
          }
        }
      } on FileSystemException {
        // A file can disappear between enumeration and hashing. Other files still scan.
        seen.remove(pathKey);
      }
      if (writes.length >= 200) await flush();
    }
    for (final row in rows) {
      if (row['folder'] == root &&
          !seen.contains(key(row['path'] as String)) &&
          !claimed.contains(row['id']) &&
          row['online'] != 0) {
        writes.add(
          (batch) => batch.update(
            'media',
            {'online': 0},
            where: 'id=?',
            whereArgs: [row['id']],
          ),
        );
      }
      if (writes.length >= 200) await flush();
    }
    await flush();
  }
}
