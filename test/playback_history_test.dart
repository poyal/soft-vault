import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/advanced_catalog.dart';
import 'package:soft_vault/library_filter.dart';
import 'package:soft_vault/playback_history.dart';
import 'package:soft_vault/file_jobs.dart';

void main() {
  late Directory root, source, target;
  late Library library;
  late int id;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('vault-history-');
    source = await Directory('${root.path}/source').create();
    target = await Directory('${root.path}/target').create();
    await File('${source.path}/one.mp4').writeAsBytes([1, 2, 3]);
    library = await Library.open('${root.path}/catalog.sqlite');
    await library.connect(source.path);
    await library.connect(target.path);
    id = (await library.items()).single['id'] as int;
  });
  tearDown(() async {
    await library.close();
    await root.delete(recursive: true);
  });

  test(
    'v3 migration preserves old played status without inventing counts',
    () async {
      await library.saveResume(
        id,
        const Duration(seconds: 8),
        const Duration(seconds: 60),
      );
      await library.db.execute('ALTER TABLE media DROP COLUMN play_count');
      await library.db.execute('PRAGMA user_version=3');
      await library.close();
      library = await Library.open('${root.path}/catalog.sqlite');
      expect((await library.mediaById(id))['play_count'], 0);
      expect(
        await library.db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='playback_history'",
        ),
        isEmpty,
      );
      expect(
        await library.items(
          filters: [LibraryFilter(playback: PlaybackFilter.unplayed)],
        ),
        isEmpty,
      );
      expect(
        (await library.items(
          filters: [LibraryFilter(playback: PlaybackFilter.played)],
        )).length,
        1,
      );
    },
  );

  test(
    'summary count is atomic, survives move and backup, resets replaced content',
    () async {
      final now = DateTime.now();
      await Future.wait(
        List.generate(
          3,
          (_) => library.recordPlayback(id, now, const Duration(seconds: 7)),
        ),
      );
      expect((await library.mediaById(id))['play_count'], 3);
      await library.db.execute(
        "CREATE TRIGGER fail_summary BEFORE UPDATE OF play_count ON media BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        library.recordPlayback(id, now, Duration.zero),
        throwsA(anything),
      );
      expect((await library.mediaById(id))['play_count'], 3);
      await library.db.execute('DROP TRIGGER fail_summary');
      await FileJobs(library).move([id], target.path);
      await library.close();
      library = await Library.open('${root.path}/catalog.sqlite');
      expect((await library.mediaById(id))['play_count'], 3);
      final backup = File('${root.path}/backup.json');
      await library.exportTo(backup);
      await library.recordPlayback(id, now, Duration.zero);
      await library.restoreFrom(backup);
      expect((await library.mediaById(id))['play_count'], 3);
      expect((await library.mediaById(id))['play_count'], 3);
      final path = (await library.mediaById(id))['path'] as String;
      await File(path).writeAsBytes([9, 8, 7, 6, 5]);
      await library.scan(target.path);
      expect((await library.mediaById(id))['play_count'], 0);
      expect(
        await library.db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='playback_history'",
        ),
        isEmpty,
      );
    },
  );

  test(
    'played filters combine with ratings and entities and persist in collections',
    () async {
      final filter = LibraryFilter(
        playback: PlaybackFilter.unplayed,
        rating: 4,
      );
      await library.edit(id, {'rating': 5, 'actors': '배우', 'tags': '태그'});
      final actor = (await library.entities('actors')).single['id'] as int;
      final tag = (await library.entities('tags')).single['id'] as int;
      final combined = filter.withIds(actors: [actor], tags: [tag]);
      expect((await library.items(filters: [combined])).length, 1);
      await library.recordPlayback(id, DateTime.now(), Duration.zero);
      expect(await library.items(filters: [combined]), isEmpty);
      final played = combined.withPlayback(PlaybackFilter.played);
      final criteria = MediaCriteria.decode(
        jsonEncode(MediaCriteria(filters: [played]).toJson()),
      );
      expect((await library.matching(criteria)).single['id'], id);
      expect(played.withoutRating().playback, PlaybackFilter.played);
      expect(LibraryFilter.fromJson({}).playback, PlaybackFilter.all);
      expect(played.groupCount, 4);
    },
  );

  test(
    'v3 backup restores and obsolete history is ignored',
    () async {
      await library.saveResume(
        id,
        const Duration(seconds: 3),
        const Duration(seconds: 60),
      );
      final backup = File('${root.path}/backup.json');
      await library.exportTo(backup);
      final data = jsonDecode(await backup.readAsString());
      data['playback_history'] = [
        {'id': 1, 'media_id': -1, 'started_at': 1, 'start_position_ms': 0},
      ];
      await backup.writeAsString(jsonEncode(data));
      await library.restoreFrom(backup);
      expect((await library.mediaById(id))['resume_ms'], 3000);
      data['version'] = 3;
      data.remove('playback_history');
      for (final row in data['media']) {
        row.remove('play_count');
      }
      await backup.writeAsString(jsonEncode(data));
      await library.restoreFrom(backup);
      expect((await library.mediaById(id))['play_count'], 0);
      expect(
        (await library.items(
          filters: [LibraryFilter(playback: PlaybackFilter.played)],
        )).length,
        1,
      );
    },
  );

  test(
    'one session ignores failures, paused state and repeated progress',
    () async {
      var calls = 0;
      final done = Completer<void>();
      final session = PlaybackSession(() {
        calls++;
        return done.future;
      });
      await session.observe(Duration.zero, const Duration(seconds: 60), true);
      await session.observe(const Duration(seconds: 1), Duration.zero, true);
      await session.observe(
        const Duration(seconds: 1),
        const Duration(seconds: 60),
        false,
      );
      expect(calls, 0);
      final one = session.observe(
        const Duration(seconds: 1),
        const Duration(seconds: 60),
        true,
      );
      final two = session.observe(
        const Duration(seconds: 20),
        const Duration(seconds: 60),
        true,
      );
      expect(calls, 1);
      done.complete();
      await Future.wait([one, two]);
      await session.observe(
        const Duration(seconds: 2),
        const Duration(seconds: 60),
        true,
      );
      expect(calls, 1);
    },
  );
}
