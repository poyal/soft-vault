import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/advanced_catalog.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/file_jobs.dart';
import 'package:soft_vault/media_tools.dart';

class ControlledTools extends MediaTools {
  final Future<void> Function() beforeExtract;
  ControlledTools(Library library, Directory cache, this.beforeExtract)
    : super(library, cache, 'unused');

  @override
  Future<ProcessResult> run(
    String tool,
    List<String> args, {
    bool Function()? cancelled,
  }) async {
    if (tool == 'ffprobe') {
      return ProcessResult(
        0,
        0,
        '{"format":{"duration":"10"},"streams":[{"codec_type":"video","codec_name":"h264","width":640,"height":360}]}',
        '',
      );
    }
    await beforeExtract();
    await File(args.last).writeAsBytes([1]);
    return ProcessResult(0, 0, '', '');
  }
}

void main() {
  late Directory root, source;
  late Library library;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('vault-fast-index-');
    source = await Directory(p.join(root.path, 'videos')).create();
    library = await Library.open(p.join(root.path, 'vault.sqlite'));
  });
  tearDown(() async {
    await library.close();
    await root.delete(recursive: true);
  });

  test(
    '174 files become a complete catalog without content fingerprints',
    () async {
      for (var i = 0; i < 174; i++) {
        await File(p.join(source.path, '$i.mp4')).writeAsBytes([i, 1, 2]);
      }
      await library.connect(source.path, verifyContents: false);
      expect(await library.items(), hasLength(174));
      expect(
        (await library.items()).every((row) => row['fingerprint'] == ''),
        isTrue,
      );
      await library.scan(source.path, verifyContents: false);
      expect(
        (await library.items()).every((row) => row['fingerprint'] == ''),
        isTrue,
      );
    },
  );

  test(
    'unverified files are not merged and offline metadata stays attached',
    () async {
      final original = await File(
        p.join(source.path, 'original.mp4'),
      ).writeAsBytes([1, 2, 3]);
      await library.connect(source.path, verifyContents: false);
      final first = (await library.items()).single;
      await library.edit(first['id'] as int, {'rating': 5});
      await original.rename(p.join(root.path, 'elsewhere.mp4'));
      await File(p.join(source.path, 'different.mp4')).writeAsBytes([3, 2, 1]);
      await library.scan(source.path, verifyContents: false);
      final rows = await library.items();
      expect(rows, hasLength(2));
      expect(rows.singleWhere((r) => r['id'] == first['id'])['rating'], 5);
      expect(rows.singleWhere((r) => r['id'] == first['id'])['online'], 0);
      expect(rows.singleWhere((r) => r['id'] != first['id'])['rating'], isNull);
    },
  );

  test(
    'moving a fast-indexed file preserves its ID and metadata with full verification',
    () async {
      await File(p.join(source.path, 'original.mp4')).writeAsBytes([1, 2, 3]);
      final target = await Directory(p.join(root.path, 'target')).create();
      await library.connect(source.path, verifyContents: false);
      await library.connect(target.path, verifyContents: false);
      final before = (await library.items()).single;
      final id = before['id'] as int;
      await library.edit(id, {'rating': 5, 'description': 'keep this'});
      await FileJobs(library).move([id], target.path, forceCopy: true);
      final after = (await library.items()).single;
      expect(after['id'], id);
      expect(after['rating'], 5);
      expect(after['description'], 'keep this');
      expect(
        after['fingerprint'],
        await Library.fingerprint(File(after['path'] as String)),
      );
    },
  );

  test(
    'verifying an unverified file fills its hash without erasing scene records',
    () async {
      await File(p.join(source.path, 'original.mp4')).writeAsBytes([1, 2, 3]);
      await library.connect(source.path, verifyContents: false);
      final id = (await library.items()).single['id'];
      await library.db.insert('bookmarks', {
        'media_id': id,
        'position_ms': 10,
        'title': 'scene',
        'created': 1,
      });
      await library.scan(source.path, verifyContents: true);
      expect((await library.items()).single['fingerprint'], isNotEmpty);
      expect(await library.bookmarks(id as int), hasLength(1));
    },
  );

  test(
    'explicit duplicate check verifies equal-size candidates only',
    () async {
      await File(p.join(source.path, 'a.mp4')).writeAsBytes([1, 2, 3]);
      await File(p.join(source.path, 'b.mp4')).writeAsBytes([1, 2, 3]);
      await File(p.join(source.path, 'c.mp4')).writeAsBytes([3, 2, 1]);
      await File(p.join(source.path, 'unique.mp4')).writeAsBytes([1, 2, 3, 4]);
      await library.connect(source.path, verifyContents: false);
      expect((await library.duplicateGroups()).single, hasLength(2));
      expect((await library.items(query: 'unique')).single['fingerprint'], '');
      expect(
        (await library.items(query: 'c.mp4')).single['fingerprint'],
        isNotEmpty,
      );
    },
  );

  test(
    'background extraction never replaces a user-selected thumbnail',
    () async {
      await File(p.join(source.path, 'a.mp4')).writeAsBytes([1]);
      await library.connect(source.path, verifyContents: false);
      final id = (await library.items()).single['id'];
      final tools = ControlledTools(
        library,
        Directory(p.join(root.path, 'cache')),
        () async {
          await library.db.update(
            'media',
            {'thumbnail': 'chosen.jpg', 'custom_thumbnail': 1},
            where: 'id=?',
            whereArgs: [id],
          );
        },
      );
      await tools.enrich();
      expect((await library.items()).single['thumbnail'], 'chosen.jpg');
      expect((await library.items()).single['custom_thumbnail'], 1);
    },
  );

  test(
    'stopping extraction preserves indexed files and skips thumbnail writes',
    () async {
      await File(p.join(source.path, 'a.mp4')).writeAsBytes([1]);
      await library.connect(source.path, verifyContents: false);
      var cancelled = false;
      final tools = ControlledTools(
        library,
        Directory(p.join(root.path, 'cache')),
        () async {
          cancelled = true;
        },
      );
      await tools.enrich(cancelled: () => cancelled);
      expect(await library.items(), hasLength(1));
      expect((await library.items()).single['thumbnail'], '');
    },
  );
}
