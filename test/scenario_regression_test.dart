import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';
import 'package:soft_vault/advanced_catalog.dart';
import 'package:soft_vault/file_jobs.dart';
import 'package:soft_vault/rule_runner.dart';

void main() {
  late Directory root, source, target;
  late Library library;
  Future<int> add(String name, [List<int> bytes = const [1, 2, 3]]) async {
    final file = await File(p.join(source.path, name)).writeAsBytes(bytes);
    await library.scan(source.path);
    return (await library.db.query(
          'media',
          where: 'path=?',
          whereArgs: [file.path],
        )).single['id']
        as int;
  }

  setUp(() async {
    root = await Directory(
      await Directory.systemTemp.resolveSymbolicLinks(),
    ).createTemp('vault-scenarios-');
    source = await Directory(p.join(root.path, 'source')).create();
    target = await Directory(p.join(root.path, 'target')).create();
    library = await Library.open(p.join(root.path, 'db.sqlite'));
    await library.connect(source.path);
    await library.connect(target.path);
  });
  tearDown(() async {
    await library.close();
    await root.delete(recursive: true);
  });
  test(
    'VIDEO-01 mixed folder indexes videos and ignores standalone images',
    () async {
      await File(p.join(source.path, 'poster.jpg')).writeAsBytes([1, 2]);
      await File(p.join(source.path, 'cover.png')).writeAsBytes([3, 4]);
      final id = await add('movie.mp4');
      expect((await library.items()).single['id'], id);
      expect((await library.db.query('media')).length, 1);
      expect(await File(p.join(source.path, 'poster.jpg')).exists(), isTrue);
    },
  );
  test(
    'VIDEO-02 legacy image records stay backed up but cannot enter video results or counts',
    () async {
      final id = await library.db.insert('media', {
        'path': p.join(source.path, 'legacy.jpg'),
        'folder': source.path,
        'title': 'legacy',
        'type': 'image',
        'added': 1,
      });
      await library.edit(id, {'actors': 'legacy actor', 'tags': 'legacy tag'});
      expect(await library.items(), isEmpty);
      expect(await library.matching(const MediaCriteria()), isEmpty);
      expect((await library.entities('actors')).single['count'], 0);
      expect((await library.entities('tags')).single['count'], 0);
      final backup = File(p.join(root.path, 'legacy.json'));
      await library.exportTo(backup);
      expect(
        (jsonDecode(await backup.readAsString())['media'] as List).single['id'],
        id,
      );
    },
  );
  test('SEARCH-01 percent is a literal filename character', () async {
    await add('100% 완료.mp4');
    await add('100일.mp4', [4]);
    expect((await library.items(query: '%')).map((r) => r['title']), [
      '100% 완료',
    ]);
  });
  test(
    'SEARCH-02 underscore is literal rather than a one-character wildcard',
    () async {
      await add('a_b.mp4');
      await add('acb.mp4', [4]);
      expect((await library.items(query: 'a_b')).map((r) => r['title']), [
        'a_b',
      ]);
    },
  );
  test('SEARCH-03 quoted Unicode and backslash remain searchable', () async {
    final id = await add('한글 日本語 🎬.mp4');
    await library.edit(id, {'note': r"C:\자료 O'Brien"});
    expect((await library.items(query: r"C:\자료 O'Brien")).single['id'], id);
  });
  test('EDIT-01 concurrent tag additions preserve both updates', () async {
    final id = await add('item.mp4');
    await Future.wait([
      library.batchEdit([id], tags: '첫째'),
      library.batchEdit([id], tags: '둘째'),
    ]);
    expect(
      (await library.mediaById(id))['tags'].toString().split(', ').toSet(),
      {'첫째', '둘째'},
    );
  });
  test(
    'EDIT-02 batch with missing item rolls back all prior changes',
    () async {
      final id = await add('item.mp4');
      await library.edit(id, {'rating': 2});
      await expectLater(
        library.batchEdit([id, 999999], rating: 5, setRating: true),
        throwsA(anything),
      );
      expect((await library.mediaById(id))['rating'], 2);
    },
  );
  test(
    'EDIT-03 batch remove keeps unrelated tags and normalized links',
    () async {
      final id = await add('item.mp4');
      await library.edit(id, {'tags': '자연, 여행, 메모'});
      await library.batchEdit([id], tags: '여행', removeTags: true);
      expect((await library.mediaById(id))['tags'], '자연, 메모');
      expect(
        (await library.matching(const MediaCriteria(tags: '여행'))),
        isEmpty,
      );
    },
  );
  test(
    'SCAN-01 overlapping root connection keeps most-specific ownership',
    () async {
      final nested = await Directory(p.join(source.path, 'nested')).create();
      await File(p.join(nested.path, 'video.mp4')).writeAsBytes([8]);
      await library.scan(source.path);
      await library.connect(nested.path);
      final item = (await library.items()).single;
      expect(item['folder'], nested.path);
      await library.disconnect(nested.path);
      await library.scan(source.path);
      expect((await library.items()).single['folder'], source.path);
      expect((await library.items()).single['online'], 1);
    },
  );
  test(
    'SCAN-02 timestamp-only change retains chosen thumbnail and playback records',
    () async {
      final id = await add('item.mp4');
      final row = await library.mediaById(id);
      await library.db.update(
        'media',
        {
          'thumbnail': 'chosen.jpg',
          'custom_thumbnail': 1,
          'duration': 60,
          'resume_ms': 10000,
        },
        where: 'id=?',
        whereArgs: [id],
      );
      await File(row['path'] as String).setLastModified(DateTime(2030));
      await library.scan(source.path);
      final after = await library.mediaById(id);
      expect(after['custom_thumbnail'], 1);
      expect(after['thumbnail'], 'chosen.jpg');
      expect(after['duration'], 60);
    },
  );
  test(
    'SCAN-03 replaced content invalidates resume, bookmarks and technical metadata',
    () async {
      final id = await add('item.mp4');
      await library.edit(id, {'note': '유지할 사용자 기록'});
      await library.db.update(
        'media',
        {
          'duration': 60,
          'resume_ms': 20000,
          'codec': 'h264',
          'resolution': '4K',
        },
        where: 'id=?',
        whereArgs: [id],
      );
      await library.saveBookmark(
        id,
        const Duration(seconds: 10),
        title: '옛 영상',
      );
      await File(p.join(source.path, 'item.mp4')).writeAsBytes([9, 8, 7, 6]);
      await library.scan(source.path);
      final row = await library.mediaById(id);
      expect(row['resume_ms'], 0);
      expect(row['codec'], '');
      expect(row['resolution'], '');
      expect(await library.bookmarks(id), isEmpty);
      expect(row['note'], '유지할 사용자 기록');
    },
  );
  test('SCAN-04 concurrent scans never duplicate identities', () async {
    for (var i = 0; i < 30; i++) {
      await File(p.join(source.path, '$i.mp4')).writeAsBytes([i]);
    }
    await Future.wait(List.generate(4, (_) => library.scan(source.path)));
    expect((await library.items()).length, 30);
    expect((await library.items()).every((r) => r['online'] == 1), isTrue);
  });
  test('MOVE-01 simultaneous submissions admit only one file job', () async {
    final id = await add('item.mp4');
    final jobs = FileJobs(library);
    final results = await Future.wait(
      List.generate(2, (_) async {
        try {
          await jobs.move([id], target.path, forceCopy: true);
          return 'accepted';
        } catch (_) {
          return 'rejected';
        }
      }),
    );
    expect(results.where((r) => r == 'accepted').length, 1);
    expect((await jobs.history()).length, 1);
    expect((await jobs.history()).single['state'], 'done');
  });
  test('MOVE-02 invalid destination releases the job lock', () async {
    final id = await add('item.mp4');
    final jobs = FileJobs(library);
    await expectLater(
      jobs.move([id], p.join(root.path, 'missing')),
      throwsA(anything),
    );
    await jobs.move([id], target.path);
    expect(jobs.running, isFalse);
    expect((await jobs.history()).single['state'], 'done');
  });
  test(
    'MOVE-03 destination disconnected before execution cannot receive files',
    () async {
      final id = await add('item.mp4');
      await library.disconnect(target.path);
      await expectLater(
        FileJobs(library).move([id], target.path),
        throwsArgumentError,
      );
      expect(await File(p.join(source.path, 'item.mp4')).exists(), isTrue);
    },
  );
  test(
    'BACKUP-01 malformed reference must roll back instead of creating orphan scenes',
    () async {
      final id = await add('item.mp4');
      await library.saveBookmark(id, Duration.zero, title: '정상');
      final file = File(p.join(root.path, 'backup.json'));
      await library.exportTo(file);
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      (data['bookmarks'] as List).first['media_id'] = 999999;
      await file.writeAsString(jsonEncode(data));
      await expectLater(library.restoreFrom(file), throwsA(anything));
      expect((await library.bookmarks(id)).single['title'], '정상');
    },
  );
  test(
    'BACKUP-02 backup captures metadata and links from one consistent snapshot',
    () async {
      final id = await add('item.mp4');
      final file = File(p.join(root.path, 'backup.json'));
      await Future.wait([
        library.exportTo(file),
        Future(() async {
          for (var i = 0; i < 10; i++) {
            await library.edit(id, {'tags': 'tag$i'});
          }
        }),
      ]);
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final row = (data['media'] as List).single;
      final links = (data['media_tags'] as List)
          .where((r) => r['media_id'] == id)
          .toList();
      final tags = (data['tags'] as List)
          .where((r) => links.any((link) => link['tag_id'] == r['id']))
          .map((r) => r['name'])
          .toSet();
      expect(
        tags,
        row['tags'] == ''
            ? <String>{}
            : row['tags'].toString().split(', ').toSet(),
      );
    },
  );
  test(
    'RULE-01 deleted destination does not silently move into unrelated folder',
    () async {
      await add('item.mp4');
      await library.saveMoveRule(
        'rule',
        MediaCriteria(folder: source.path),
        target.path,
        enabled: true,
      );
      await library.disconnect(target.path);
      await expectLater(
        RuleRunner(library, FileJobs(library)).runAutomatic(),
        throwsArgumentError,
      );
      expect(await File(p.join(source.path, 'item.mp4')).exists(), isTrue);
    },
  );
}
