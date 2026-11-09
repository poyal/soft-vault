import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/library_filter.dart';
import 'package:soft_vault/advanced_catalog.dart';

void main() {
  late Directory root;
  late Library lib;
  late List<int> ids;
  late int a, b, t, u;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('filters-');
    lib = await Library.open('${root.path}/db');
    ids = [];
    for (var i = 0; i < 4; i++) {
      ids.add(
        await lib.db.insert('media', {
          'path': '${root.path}/$i.mp4',
          'folder': root.path,
          'title': 'video$i',
          'type': 'video',
          'added': i,
        }),
      );
    }
    await lib.edit(ids[0], {
      'rating': 4,
      'actors': 'Alice, Bob',
      'tags': 'A, B',
    });
    await lib.edit(ids[1], {'rating': 5, 'actors': 'Alice', 'tags': 'A'});
    await lib.edit(ids[2], {'rating': 3, 'actors': 'Alicia', 'tags': 'B'});
    final actors = await lib.entities('actors'),
        tags = await lib.entities('tags');
    a = actors.firstWhere((r) => r['name'] == 'Alice')['id'] as int;
    b = actors.firstWhere((r) => r['name'] == 'Bob')['id'] as int;
    t = tags.firstWhere((r) => r['name'] == 'A')['id'] as int;
    u = tags.firstWhere((r) => r['name'] == 'B')['id'] as int;
  });
  tearDown(() async {
    await lib.close();
    await root.delete(recursive: true);
  });
  Future<List<int>> find(LibraryFilter filter) async =>
      (await lib.items(filters: [filter])).map((r) => r['id'] as int).toList();
  test('rating modes, unrated and boundaries', () async {
    expect(await find(LibraryFilter(rating: 4)), unorderedEquals(ids.take(2)));
    expect(await find(LibraryFilter(rating: 4, exact: true)), [ids[0]]);
    expect(await find(LibraryFilter(unrated: true)), [ids[3]]);
    for (var rating = 1; rating <= 5; rating++) {
      expect(
        (await find(LibraryFilter(rating: rating))).length,
        [3, 3, 3, 2, 1][rating - 1],
      );
    }
    expect(() => LibraryFilter(rating: 0), throwsArgumentError);
  });
  test('actor and tag any/all use exact IDs without duplicates', () async {
    expect(
      await find(LibraryFilter(actorIds: [a, b])),
      unorderedEquals(ids.take(2)),
    );
    expect(await find(LibraryFilter(actorIds: [a, b], actorsAll: true)), [
      ids[0],
    ]);
    expect(await find(LibraryFilter(tagIds: [t, u])), [ids[0]]);
    expect(
      await find(LibraryFilter(tagIds: [t, u], tagsAll: false)),
      unorderedEquals(ids.take(3)),
    );
    expect(await find(LibraryFilter(actorIds: [a], tagIds: [u], rating: 4)), [
      ids[0],
    ]);
    expect(
      await find(LibraryFilter(actorIds: [a, a])),
      unorderedEquals(ids.take(2)),
    );
  });
  test(
    'rename does not change identity; deleted IDs do not broaden query',
    () async {
      await lib.db.update(
        'actors',
        {'name': "O'Brien %_", 'alias': 'Alias'},
        where: 'id=?',
        whereArgs: [a],
      );
      expect(
        await find(LibraryFilter(actorIds: [a])),
        unorderedEquals(ids.take(2)),
      );
      await lib.db.delete('media_actors', where: 'actor_id=?', whereArgs: [a]);
      await lib.db.delete('actors', where: 'id=?', whereArgs: [a]);
      expect(await find(LibraryFilter(actorIds: [a])), isEmpty);
    },
  );
  test(
    'collection, legacy criteria and backup retain additional filters',
    () async {
      final criteria = MediaCriteria(
        query: 'video',
        filters: [
          LibraryFilter(actorIds: [a]),
          LibraryFilter(tagIds: [u], rating: 4, exact: true),
        ],
      );
      await lib.saveCollection('filtered', criteria);
      final saved = MediaCriteria.decode(
        (await lib.collections()).single['criteria'] as String,
      );
      expect((await lib.matching(saved)).single['id'], ids[0]);
      expect(
        await lib.matching(saved, filters: [LibraryFilter(rating: 5)]),
        isEmpty,
      );
      final legacy = MediaCriteria.fromJson({
        'minimumRating': 4,
        'actor': 'Alice',
      });
      expect(legacy.filters, isEmpty);
      expect((await lib.matching(legacy)).length, 2);
      final backup = File('${root.path}/backup.json');
      await lib.exportTo(backup);
      await lib.restoreFrom(backup);
      expect(
        (await lib.matching(
          MediaCriteria.decode(
            (await lib.collections()).single['criteria'] as String,
          ),
        )).single['id'],
        ids[0],
      );
    },
  );
}
