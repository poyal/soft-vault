import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';
import 'package:soft_vault/file_jobs.dart';

void main() {
  late Directory root, source, destination;
  late Library library;
  setUp(() async {
    root = await Directory(
      await Directory.systemTemp.resolveSymbolicLinks(),
    ).createTemp('vault-jobs-');
    source = await Directory(p.join(root.path, 'source')).create();
    destination = await Directory(p.join(root.path, 'destination')).create();
    await File(
      p.join(source.path, '한글 영상.mkv'),
    ).writeAsBytes(List.generate(10000, (i) => i % 256));
    library = await Library.open(p.join(root.path, 'db.sqlite'));
    await library.connect(source.path);
    await library.connect(destination.path);
    await library.edit((await library.items()).single['id'] as int, {
      'rating': 4,
      'tags': '여행, 자연',
      'actors': '배우',
      'note': '개인 메모',
    });
  });
  tearDown(() async {
    await library.close();
    await root.delete(recursive: true);
  });
  for (final forceCopy in [false, true]) {
    test('verified move preserves ID and metadata (copy=$forceCopy)', () async {
      final before = (await library.items()).single;
      await FileJobs(
        library,
      ).move([before['id'] as int], destination.path, forceCopy: forceCopy);
      final after = (await library.items()).single;
      expect(after['id'], before['id']);
      expect(after['rating'], 4);
      expect(after['tags'], '여행, 자연');
      expect(after['note'], '개인 메모');
      expect(await File(before['path'] as String).exists(), isFalse);
      expect(
        await Library.fingerprint(File(after['path'] as String)),
        before['fingerprint'],
      );
    });
  }
  test(
    'collision skips without replacing; auto rename preserves both files',
    () async {
      final item = (await library.items()).single;
      final collision = File(p.join(destination.path, '한글 영상.mkv'));
      await collision.writeAsString('existing');
      final jobs = FileJobs(library);
      await jobs.move([item['id'] as int], destination.path);
      expect(await collision.readAsString(), 'existing');
      expect(await File(item['path'] as String).exists(), isTrue);
      expect((await jobs.history()).first['state'], 'skipped');
      await jobs.move([item['id'] as int], destination.path, autoRename: true);
      expect(await collision.readAsString(), 'existing');
      expect((await library.items()).single['path'], contains('(1)'));
    },
  );
  test(
    'recovery after publication completes metadata and source cleanup',
    () async {
      final item = (await library.items()).single;
      final jobs = FileJobs(
        library,
        checkpoint: (phase) {
          if (phase == 'published') throw StateError('simulated crash');
        },
      );
      await jobs.move([item['id'] as int], destination.path, forceCopy: true);
      expect(await File(item['path'] as String).exists(), isTrue);
      await FileJobs(library).recover();
      expect(await File(item['path'] as String).exists(), isFalse);
      expect((await library.items()).single['folder'], destination.path);
    },
  );
  test('copy failure retains original and retry completes', () async {
    final item = (await library.items()).single;
    await FileJobs(
      library,
      checkpoint: (phase) {
        if (phase == 'copied') throw StateError('disk failure');
      },
    ).move([item['id'] as int], destination.path, forceCopy: true);
    expect(await File(item['path'] as String).exists(), isTrue);
    final jobs = FileJobs(library);
    await jobs.retry();
    expect((await library.items()).single['folder'], destination.path);
  });
  test(
    'external rename reconnects one missing identity; copies stay separate',
    () async {
      final item = (await library.items()).single;
      await File(
        item['path'] as String,
      ).rename(p.join(source.path, 'renamed.mkv'));
      await library.scan(source.path);
      expect((await library.items()).single['id'], item['id']);
      await File(
        p.join(source.path, 'renamed.mkv'),
      ).copy(p.join(source.path, 'copy.mkv'));
      await library.scan(source.path);
      expect((await library.items()).length, 2);
    },
  );
  test(
    'backup restore and normalized tag merge preserve associations',
    () async {
      await library.renameTag('자연', '여행');
      expect((await library.items()).single['tags'], '여행');
      expect((await library.entities('tags')).single['count'], 1);
      final backup = File(p.join(root.path, 'backup.json'));
      await library.exportTo(backup);
      await library.edit((await library.items()).single['id'] as int, {
        'title': 'changed',
      });
      await library.restoreFrom(backup);
      expect((await library.items()).single['title'], '한글 영상');
    },
  );
  test('cancelled copy preserves source and does not publish', () async {
    final item = (await library.items()).single;
    late FileJobs jobs;
    jobs = FileJobs(
      library,
      checkpoint: (phase) {
        if (phase == 'planned') jobs.cancelled = true;
      },
    );
    await jobs.move([item['id'] as int], destination.path, forceCopy: true);
    expect(await File(item['path'] as String).exists(), isTrue);
    expect(await destination.list().isEmpty, isTrue);
    expect((await jobs.history()).first['state'], 'cancelled');
  });
  test('changed destination is never trusted by recovery', () async {
    final item = (await library.items()).single;
    await FileJobs(
      library,
      checkpoint: (phase) {
        if (phase == 'published') throw StateError('crash');
      },
    ).move([item['id'] as int], destination.path, forceCopy: true);
    final target = File(
      p.join(destination.path, p.basename(item['path'] as String)),
    );
    await target.writeAsString('changed destination');
    await FileJobs(library).recover();
    expect(await File(item['path'] as String).exists(), isTrue);
    expect(await target.readAsString(), 'changed destination');
  });
  test('nested rename preserves library root and metadata', () async {
    final nested = await Directory(p.join(source.path, 'sub')).create();
    final file = await File(
      p.join(nested.path, 'nested.mp4'),
    ).writeAsString('different media');
    await library.scan(source.path);
    final item = (await library.items(query: 'nested')).single;
    await FileJobs(
      library,
    ).move([item['id'] as int], nested.path, filename: 'renamed.mp4');
    final after = (await library.items(query: 'renamed.mp4')).single;
    expect(after['folder'], source.path);
    expect(after['id'], item['id']);
    expect(await file.exists(), isFalse);
  });
  test('offline catalogs retain metadata and explicitly reconnect', () async {
    final item = (await library.items()).single;
    await library.disconnect(source.path);
    expect((await library.items()).single['online'], 0);
    await library.connect(source.path);
    expect((await library.items()).single['id'], item['id']);
    expect((await library.items()).single['rating'], 4);
    expect((await library.items()).single['online'], 1);
  });
  test('malformed restore rolls back instead of erasing the catalog', () async {
    final backup = File(p.join(root.path, 'invalid.json'));
    await backup.writeAsString(
      '{"version":2,"folders":[],"media":[{"unknown":1}],"actors":[],"tags":[],"media_actors":[],"media_tags":[],"settings":[]}',
    );
    await expectLater(library.restoreFrom(backup), throwsA(anything));
    expect((await library.items()).single['rating'], 4);
  });
  test(
    'manual relink verifies content and requires explicit duplicate replacement',
    () async {
      final item = (await library.items()).single;
      final copied = await File(
        item['path'] as String,
      ).copy(p.join(destination.path, 'copy.mp4'));
      await library.scan(destination.path);
      await expectLater(
        library.relink(item['id'] as int, copied.path),
        throwsStateError,
      );
      await library.relink(
        item['id'] as int,
        copied.path,
        replaceIndexEntry: true,
      );
      final after = (await library.items()).single;
      expect(after['id'], item['id']);
      expect(after['rating'], 4);
      expect(await File(item['path'] as String).exists(), isTrue);
      final wrong = await File(
        p.join(destination.path, 'wrong.mp4'),
      ).writeAsString('wrong content');
      await expectLater(
        library.relink(item['id'] as int, wrong.path),
        throwsStateError,
      );
      expect((await library.items()).single['path'], copied.path);
    },
  );
  test(
    'actor aliases, private notes and combined filters survive editing',
    () async {
      final item = (await library.items()).single;
      await library.edit(item['id'] as int, {'actors': '배우', 'note': '개인 메모'});
      final actor = (await library.entities('actors')).single;
      await library.saveActor(
        id: actor['id'] as int,
        name: '배우',
        alias: 'Alias',
        description: '소개',
      );
      expect(
        (await library.items(
          query: 'Alias',
          minimumRating: 4,
          type: 'video',
          folder: source.path,
        )).length,
        1,
      );
      expect((await library.items(query: '개인 메모')).length, 1);
      expect(await library.items(minimumRating: 5), isEmpty);
      expect(await library.items(unrated: true), isEmpty);
    },
  );
}
