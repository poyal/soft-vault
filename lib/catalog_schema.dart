import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> upgradeFeatures(Database db) async {
  for (final declaration in [
    'resume_ms INTEGER NOT NULL DEFAULT 0',
    'watched INTEGER NOT NULL DEFAULT 0',
    'last_played INTEGER NOT NULL DEFAULT 0',
    'custom_thumbnail INTEGER NOT NULL DEFAULT 0',
  ]) {
    await db.execute('ALTER TABLE media ADD COLUMN $declaration');
  }
  await db.execute(
    'CREATE TABLE bookmarks (id INTEGER PRIMARY KEY, media_id INTEGER NOT NULL, position_ms INTEGER NOT NULL CHECK(position_ms >= 0), title TEXT NOT NULL, note TEXT NOT NULL DEFAULT \'\', created INTEGER NOT NULL)',
  );
  await db.execute(
    'CREATE INDEX bookmarks_media ON bookmarks(media_id, position_ms)',
  );
  await db.execute(
    'CREATE TABLE collections (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, criteria TEXT NOT NULL, created INTEGER NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE move_rules (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, criteria TEXT NOT NULL, destination TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 0, auto_rename INTEGER NOT NULL DEFAULT 0, updated INTEGER NOT NULL)',
  );
}

Future<void> upgradeCatalog(Database db) async {
  for (final declaration in [
    "note TEXT NOT NULL DEFAULT ''",
    'size INTEGER NOT NULL DEFAULT 0',
    'modified INTEGER NOT NULL DEFAULT 0',
    "fingerprint TEXT NOT NULL DEFAULT ''",
    'duration REAL NOT NULL DEFAULT 0',
    "thumbnail TEXT NOT NULL DEFAULT ''",
    "codec TEXT NOT NULL DEFAULT ''",
    "resolution TEXT NOT NULL DEFAULT ''",
    'online INTEGER NOT NULL DEFAULT 1',
  ]) {
    await db.execute('ALTER TABLE media ADD COLUMN $declaration');
  }
  await db.execute(
    "CREATE TABLE actors (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, alias TEXT NOT NULL DEFAULT '', image TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '')",
  );
  await db.execute(
    'CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)',
  );
  await db.execute(
    'CREATE TABLE media_actors (media_id INTEGER, actor_id INTEGER, PRIMARY KEY(media_id, actor_id))',
  );
  await db.execute(
    'CREATE TABLE media_tags (media_id INTEGER, tag_id INTEGER, PRIMARY KEY(media_id, tag_id))',
  );
  await db.execute(
    'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  );
  await db.execute(
    '''CREATE TABLE jobs (id INTEGER PRIMARY KEY, media_id INTEGER NOT NULL,
    source TEXT NOT NULL, destination TEXT NOT NULL, temporary TEXT NOT NULL,
    fingerprint TEXT NOT NULL, state TEXT NOT NULL, error TEXT NOT NULL DEFAULT '',
    created INTEGER NOT NULL)''',
  );
  for (final item in await db.query('media')) {
    await setRelations(
      db,
      item['id'] as int,
      'actors',
      item['actors'] as String,
    );
    await setRelations(db, item['id'] as int, 'tags', item['tags'] as String);
  }
}

List<String> names(String value) => value
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toSet()
    .toList();

Future<void> setRelations(
  DatabaseExecutor db,
  int id,
  String kind,
  String value,
) async {
  final column = kind == 'actors' ? 'actor_id' : 'tag_id';
  await db.delete('media_$kind', where: 'media_id = ?', whereArgs: [id]);
  for (final name in names(value)) {
    await db.insert(kind, {
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final entity = (await db.query(
      kind,
      where: 'name = ?',
      whereArgs: [name],
    )).single;
    await db.insert('media_$kind', {'media_id': id, column: entity['id']});
  }
}
