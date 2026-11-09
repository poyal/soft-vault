import 'library_filter.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'library.dart';
import 'catalog_schema.dart';

class MediaCriteria {
  final List<LibraryFilter> filters;
  final String query, tags, actor;
  final String? folder, type;
  final int? minimumRating;
  final bool unrated, unfinished, onlineOnly;
  const MediaCriteria({
    this.filters = const [],
    this.query = '',
    this.tags = '',
    this.actor = '',
    this.folder,
    this.type,
    this.minimumRating,
    this.unrated = false,
    this.unfinished = false,
    this.onlineOnly = false,
  });
  Map<String, Object?> toJson() => {
    'filters': filters.map((f) => f.toJson()).toList(),
    'query': query,
    'tags': tags,
    'actor': actor,
    'folder': folder,
    'type': type,
    'minimumRating': minimumRating,
    'unrated': unrated,
    'unfinished': unfinished,
    'onlineOnly': onlineOnly,
  };
  factory MediaCriteria.fromJson(Map<String, dynamic> json) => MediaCriteria(
    filters: (json['filters'] as List? ?? [])
        .map((f) => LibraryFilter.fromJson(Map<String, dynamic>.from(f as Map)))
        .toList(),
    query: json['query'] as String? ?? '',
    tags: json['tags'] as String? ?? '',
    actor: json['actor'] as String? ?? '',
    folder: json['folder'] as String?,
    type: json['type'] as String?,
    minimumRating: json['minimumRating'] as int?,
    unrated: json['unrated'] == true,
    unfinished: json['unfinished'] == true,
    onlineOnly: json['onlineOnly'] == true,
  );
  factory MediaCriteria.decode(String json) =>
      MediaCriteria.fromJson(jsonDecode(json) as Map<String, dynamic>);
  String get summary => [
    ...filters.where((f) => !f.isEmpty).map((f) => f.summary),
    if (query.isNotEmpty) query,
    if (folder != null) p.basename(folder!),
    if (type == 'video') '영상',
    if (minimumRating != null) '$minimumRating점 이상',
    if (unrated) '미평가',
    if (tags.isNotEmpty) '#$tags',
    if (actor.isNotEmpty) actor,
    if (unfinished) '이어보기',
    if (onlineOnly) '온라인',
  ].join(' · ');
}

extension AdvancedCatalog on Library {
  Future<List<Map<String, Object?>>> matching(
    MediaCriteria criteria, {
    String sort = 'recent',
    List<LibraryFilter> filters = const [],
  }) async {
    final rows = await items(
      filters: [...criteria.filters, ...filters],
      query: criteria.query,
      folder: criteria.folder,
      type: criteria.type,
      minimumRating: criteria.minimumRating,
      unrated: criteria.unrated,
      sort: sort,
    );
    final requiredTags = names(
      criteria.tags,
    ).map((s) => s.toLowerCase()).toSet();
    Set<int>? actorIds;
    if (criteria.actor.trim().isNotEmpty) {
      final actor = criteria.actor.trim().toLowerCase();
      final entities = await db.rawQuery(
        'SELECT r.media_id, a.name, a.alias FROM media_actors r JOIN actors a ON a.id=r.actor_id',
      );
      actorIds = entities
          .where(
            (row) =>
                (row['name'] as String).toLowerCase() == actor ||
                names(
                  row['alias'] as String,
                ).any((value) => value.toLowerCase() == actor),
          )
          .map((row) => row['media_id'] as int)
          .toSet();
    }
    return rows
        .where(
          (row) =>
              (!criteria.onlineOnly || row['online'] == 1) &&
              (!criteria.unfinished ||
                  ((row['resume_ms'] as int) > 0 && row['watched'] == 0)) &&
              (actorIds == null || actorIds.contains(row['id'])) &&
              names(
                row['tags'] as String,
              ).map((s) => s.toLowerCase()).toSet().containsAll(requiredTags),
        )
        .toList();
  }

  Future<Map<String, Object?>> mediaById(int id) async =>
      (await db.query('media', where: 'id=?', whereArgs: [id])).single;
  Future<void> saveResume(
    int id,
    Duration position,
    Duration duration, {
    bool completed = false,
  }) async {
    final end = duration.inMilliseconds;
    final ms = end > 0
        ? position.inMilliseconds.clamp(0, end)
        : position.inMilliseconds.clamp(0, 1 << 50);
    final finished =
        completed || (end > 0 && ms >= end - 1000 && ms >= end * .95);
    await db.update(
      'media',
      {
        'resume_ms': finished ? 0 : ms,
        'watched': finished ? 1 : 0,
        'last_played': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> bookmarks(int mediaId) => db.query(
    'bookmarks',
    where: 'media_id=?',
    whereArgs: [mediaId],
    orderBy: 'position_ms, id',
  );
  Future<int> saveBookmark(
    int mediaId,
    Duration position, {
    int? id,
    required String title,
    String note = '',
  }) async {
    final media = await mediaById(mediaId);
    if (media['type'] != 'video' || position.isNegative || title.trim().isEmpty)
      throw ArgumentError('장면 이름과 영상 위치를 확인하세요.');
    final values = {
      'media_id': mediaId,
      'position_ms': position.inMilliseconds,
      'title': title.trim(),
      'note': note,
      'created': DateTime.now().millisecondsSinceEpoch,
    };
    if (id != null) {
      await db.update(
        'bookmarks',
        values,
        where: 'id=? AND media_id=?',
        whereArgs: [id, mediaId],
      );
      return id;
    }
    return db.insert('bookmarks', values);
  }

  Future<void> deleteBookmark(int id) async =>
      db.delete('bookmarks', where: 'id=?', whereArgs: [id]);
  Future<List<Map<String, Object?>>> collections() =>
      db.query('collections', orderBy: 'name COLLATE NOCASE');
  Future<int> saveCollection(
    String name,
    MediaCriteria criteria, {
    int? id,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('컬렉션 이름을 입력하세요.');
    final values = {
      'name': name.trim(),
      'criteria': jsonEncode(criteria.toJson()),
      'created': DateTime.now().millisecondsSinceEpoch,
    };
    if (id != null) {
      await db.update('collections', values, where: 'id=?', whereArgs: [id]);
      return id;
    }
    return db.insert('collections', values);
  }

  Future<void> deleteCollection(int id) async =>
      db.delete('collections', where: 'id=?', whereArgs: [id]);
  Future<List<List<Map<String, Object?>>>> duplicateGroups({
    bool similar = false,
  }) async {
    final groups = <String, List<Map<String, Object?>>>{};
    for (final row in await items(sort: 'name')) {
      final hash = row['fingerprint'] as String;
      final duration = (row['duration'] as num).toDouble();
      final key = similar
          ? '${row['type']}:${row['resolution']}:${duration.round()}'
          : hash;
      if (key.isEmpty || (similar && (row['type'] != 'video' || duration <= 0)))
        continue;
      groups.putIfAbsent(key, () => []).add(row);
    }
    return groups.values
        .where(
          (rows) =>
              rows.length > 1 &&
              (!similar ||
                  rows.map((row) => row['fingerprint']).toSet().length > 1),
        )
        .toList();
  }

  Future<List<Map<String, Object?>>> moveRules() =>
      db.query('move_rules', orderBy: 'id');
  Future<int> saveMoveRule(
    String name,
    MediaCriteria criteria,
    String destination, {
    int? id,
    bool enabled = false,
    bool autoRename = false,
  }) async {
    if (criteria.folder != null) {
      criteria = MediaCriteria.fromJson({
        ...criteria.toJson(),
        'folder': await Library.canonicalPath(criteria.folder!),
      });
    }
    destination = await Library.canonicalPath(destination);
    final roots = await folders();
    if (name.trim().isEmpty ||
        criteria.folder == null ||
        !roots.contains(criteria.folder) ||
        !roots.contains(destination))
      throw ArgumentError('이름과 연결된 출발·목적지 폴더가 필요합니다.');
    if (p.equals(criteria.folder!, destination) ||
        p.isWithin(criteria.folder!, destination) ||
        p.isWithin(destination, criteria.folder!))
      throw ArgumentError('출발·목적지는 서로 겹치지 않는 폴더를 선택하세요.');
    final rules = (await moveRules())
        .where((rule) => rule['id'] != id && rule['enabled'] == 1)
        .toList();
    if (enabled) {
      final edges = <String, List<String>>{};
      for (final rule in rules) {
        final from = MediaCriteria.decode(rule['criteria'] as String).folder!;
        edges.putIfAbsent(from, () => []).add(rule['destination'] as String);
      }
      edges.putIfAbsent(criteria.folder!, () => []).add(destination);
      bool cyclic(String node, Set<String> path) =>
          path.contains(node) ||
          (edges[node] ?? []).any((next) => cyclic(next, {...path, node}));
      if (edges.keys.any((node) => cyclic(node, {})))
        throw ArgumentError('자동 이동이 반복되는 순환 규칙은 저장할 수 없습니다.');
    }
    final values = {
      'name': name.trim(),
      'criteria': jsonEncode(criteria.toJson()),
      'destination': destination,
      'enabled': enabled ? 1 : 0,
      'auto_rename': autoRename ? 1 : 0,
      'updated': DateTime.now().microsecondsSinceEpoch,
    };
    if (id != null) {
      await db.update('move_rules', values, where: 'id=?', whereArgs: [id]);
      return id;
    }
    return db.insert('move_rules', values);
  }

  Future<void> deleteMoveRule(int id) async =>
      db.delete('move_rules', where: 'id=?', whereArgs: [id]);
  Future<bool> verifyDuplicate(int first, int second) async {
    final a = await mediaById(first), b = await mediaById(second);
    if (first == second || a['online'] != 1 || b['online'] != 1) return false;
    return await Library.fingerprint(File(a['path'] as String)) ==
        await Library.fingerprint(File(b['path'] as String));
  }
}
