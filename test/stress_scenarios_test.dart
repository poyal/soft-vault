import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';
import 'package:soft_vault/file_jobs.dart';
import 'package:soft_vault/advanced_catalog.dart';

void main() {
  late Directory root, source, target;
  late Library library;
  final results = <Map<String, Object?>>[];
  setUp(() async {
    root = await Directory(
      await Directory.systemTemp.resolveSymbolicLinks(),
    ).createTemp('vault-stress-');
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
  Future<int> add(String name, int value) async {
    await File(p.join(source.path, name)).writeAsString('media-$value');
    await library.scan(source.path);
    return (await library.items()).firstWhere(
          (r) => r['title'] == p.basenameWithoutExtension(name),
        )['id']
        as int;
  }

  void scenario(
    String name,
    Future<void> Function(Map<String, Object?>) action,
  ) {
    test(
      name,
      () async {
        final watch = Stopwatch()..start();
        final result = <String, Object?>{
          'name': name,
          'passed': false,
          'rssBefore': ProcessInfo.currentRss,
        };
        try {
          await action(result);
          result['passed'] = true;
        } catch (e) {
          result['error'] = '$e';
          rethrow;
        } finally {
          result['ms'] = watch.elapsedMilliseconds;
          result['rssAfter'] = ProcessInfo.currentRss;
          results.add(result);
          await Directory('build/verification').create(recursive: true);
          await File(
            'build/verification/stress-results.json',
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
      tags: 'stress',
    );
  }

  scenario('STRESS-01 200 overlapping metadata updates lose no tags', (
    result,
  ) async {
    final id = await add('video.mp4', 1);
    for (var wave = 0; wave < 20; wave++) {
      await Future.wait(
        List.generate(
          10,
          (i) => library.batchEdit([id], tags: 'tag-${wave * 10 + i}'),
        ),
      );
    }
    expect(
      (await library.mediaById(id))['tags'].toString().split(', ').length,
      200,
    );
    expect((await library.db.query('media_tags')).length, 200);
    result['operations'] = 200;
  });
  scenario('STRESS-02 96 verified moves preserve IDs, scenes and hashes', (
    result,
  ) async {
    for (var i = 0; i < 24; i++) {
      await File(
        p.join(source.path, '$i.mp4'),
      ).writeAsString('unique-content-$i');
    }
    await library.scan(source.path);
    final rows = await library.items();
    final ids = rows.map((r) => r['id'] as int).toList();
    await library.batchEdit(ids, rating: 4, setRating: true, tags: 'stress');
    await library.saveBookmark(
      ids.first,
      const Duration(seconds: 3),
      title: '유지',
    );
    final jobs = FileJobs(library);
    for (var round = 0; round < 4; round++) {
      await jobs.move(
        ids,
        round.isEven ? target.path : source.path,
        forceCopy: round.isEven,
      );
    }
    for (final before in rows) {
      final after = await library.mediaById(before['id'] as int);
      expect(after['fingerprint'], before['fingerprint']);
      expect(after['rating'], 4);
      expect(after['folder'], source.path);
    }
    expect(
      (await jobs.history()).where((r) => r['state'] == 'done').length,
      96,
    );
    expect((await library.bookmarks(ids.first)).single['title'], '유지');
    expect(await target.list().isEmpty, isTrue);
    result['moves'] = 96;
  });
  scenario(
    'STRESS-03 64 MiB verified copy measures throughput and peak memory',
    (result) async {
      final file = File(p.join(source.path, 'large.mp4'));
      final sink = file.openWrite();
      final block = List<int>.generate(1024 * 1024, (i) => i % 251);
      for (var i = 0; i < 64; i++) {
        sink.add(block);
        await sink.flush();
      }
      await sink.close();
      await library.scan(source.path);
      final before = (await library.items()).single;
      final watch = Stopwatch()..start();
      await FileJobs(
        library,
      ).move([before['id'] as int], target.path, forceCopy: true);
      watch.stop();
      final after = await library.mediaById(before['id'] as int);
      expect(
        await Library.fingerprint(File(after['path'] as String)),
        before['fingerprint'],
      );
      expect(await file.exists(), isFalse);
      result['bytes'] = 64 * 1024 * 1024;
      result['copyMs'] = watch.elapsedMilliseconds;
      result['MiBPerSecond'] = 64000 / watch.elapsedMilliseconds;
      result['maxRss'] = ProcessInfo.maxRss;
      expect(watch.elapsed, lessThan(const Duration(seconds: 45)));
    },
  );
  for (final mode in ['cancel', 'disk-full']) {
    scenario(
      'FAULT-$mode interruption during streaming copy preserves source and permits retry',
      (result) async {
        final file = File(p.join(source.path, 'interrupted.mp4'));
        await file.writeAsBytes(List<int>.filled(2 * 1024 * 1024, 42));
        await library.scan(source.path);
        final row = (await library.items()).single;
        late FileJobs jobs;
        var chunks = 0;
        jobs = FileJobs(
          library,
          checkpoint: (phase) {
            if (phase == 'copy_chunk' && ++chunks == 1) {
              if (mode == 'cancel') {
                jobs.cancelled = true;
              } else {
                throw FileSystemException(
                  'Injected disk full',
                  target.path,
                  const OSError('No space left', 112),
                );
              }
            }
          },
        );
        await jobs.move([row['id'] as int], target.path, forceCopy: true);
        expect(chunks, greaterThan(0));
        expect(await Library.fingerprint(file), row['fingerprint']);
        expect(
          await File(p.join(target.path, 'interrupted.mp4')).exists(),
          isFalse,
        );
        expect(
          (await jobs.history()).single['state'],
          mode == 'cancel' ? 'cancelled' : 'failed',
        );
        final retry = FileJobs(library);
        await retry.recover();
        if (mode == 'cancel') {
          await retry.move([row['id'] as int], target.path, forceCopy: true);
        } else {
          await retry.retry();
        }
        final after = await library.mediaById(row['id'] as int);
        expect(after['folder'], target.path);
        expect(
          await Library.fingerprint(File(after['path'] as String)),
          row['fingerprint'],
        );
        expect(await target.list().length, 1);
        result['faultInjectedAfterChunks'] = chunks;
      },
    );
  }
  for (final phase in ['copied', 'published']) {
    scenario(
      'CRASH-$phase separate process exits mid-move, reopen recovers safely',
      (result) async {
        final id = await add('crash.mp4', 5);
        final before = await library.mediaById(id);
        final dbPath = library.db.path;
        await library.close();
        final dart = p.join(
          Directory.current.path,
          '.tools',
          'flutter',
          'bin',
          'cache',
          'dart-sdk',
          'bin',
          'dart.exe',
        );
        final process = await Process.run(dart, [
          'run',
          'tool/crash_move_worker.dart',
          dbPath,
          '$id',
          target.path,
          phase,
        ]);
        library = await Library.open(dbPath);
        expect(
          process.exitCode,
          93,
          reason: '${process.stdout}\n${process.stderr}',
        );
        final jobs = FileJobs(library);
        await jobs.recover();
        if (phase == 'copied') {
          expect(await File(before['path'] as String).exists(), isTrue);
          expect(await target.list().isEmpty, isTrue);
          await jobs.retry();
        }
        final after = await library.mediaById(id);
        expect(after['folder'], target.path);
        expect(
          await Library.fingerprint(File(after['path'] as String)),
          before['fingerprint'],
        );
        expect(await File(before['path'] as String).exists(), isFalse);
        result['exitCode'] = process.exitCode;
        result['recovered'] = true;
      },
    );
  }
  scenario(
    'STRESS-04 filesystem churn and 30 queued scans converge without duplicates',
    (result) async {
      for (var wave = 0; wave < 10; wave++) {
        for (var i = 0; i < 20; i++) {
          await File(
            p.join(source.path, '$wave-$i.mp4'),
          ).writeAsString('unique-$wave-$i');
        }
        await Future.wait(List.generate(3, (_) => library.scan(source.path)));
        for (var i = 0; i < 10; i++) {
          await File(p.join(source.path, '$wave-$i.mp4')).delete();
        }
      }
      await library.scan(source.path);
      final rows = await library.items();
      expect(rows.length, 200);
      expect(rows.where((r) => r['online'] == 1).length, 100);
      expect(rows.map((r) => r['path']).toSet().length, 200);
      result['created'] = 200;
      result['deleted'] = 100;
      result['scans'] = 31;
    },
  );
  scenario(
    'STRESS-05 25 interleaved backups and edits always restore consistent relations',
    (result) async {
      final id = await add('backup.mp4', 9);
      for (var round = 0; round < 25; round++) {
        final file = File(p.join(root.path, 'snapshot-$round.json'));
        await Future.wait([
          library.exportTo(file),
          library.batchEdit([id], tags: 'tag$round'),
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
      }
      result['snapshots'] = 25;
    },
  );
}
