import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';
import 'package:soft_vault/advanced_catalog.dart';

void main() {
  test(
    'LOAD-01 real files scan, warm rescan, search, batch edit and backup',
    () async {
      final count = int.parse(
        Platform.environment['VAULT_FILE_COUNT'] ?? '1000',
      );
      final label = Platform.environment['VAULT_BENCH_LABEL'] ?? 'current';
      final root = await Directory(
        await Directory.systemTemp.resolveSymbolicLinks(),
      ).createTemp('vault-load-');
      final source = await Directory(p.join(root.path, 'media')).create();
      final library = await Library.open(p.join(root.path, 'db.sqlite'));
      final metrics = <String, Object?>{
        'files': count,
        'mode': 'Dart test service benchmark',
        'label': label,
        'os': Platform.operatingSystemVersion,
        'rssStart': ProcessInfo.currentRss,
      };
      Future<T> measure<T>(String name, Future<T> Function() action) async {
        final watch = Stopwatch()..start();
        final result = await action();
        metrics[name] = watch.elapsedMilliseconds;
        return result;
      }

      try {
        await measure('fixtureMs', () async {
          for (var i = 0; i < count; i++) {
            await File(
              p.join(source.path, '영상-${i.toString().padLeft(6, '0')}.mp4'),
            ).writeAsString('unique-fixture-$i');
          }
        });
        await measure('coldScanMs', () => library.connect(source.path));
        await measure('warmScanMs', () => library.scan(source.path));
        final rows = await measure('listMs', () => library.items());
        expect(rows.length, count);
        final samples = <int>[];
        for (var i = 0; i < 30; i++) {
          final watch = Stopwatch()..start();
          final found = await library.items(
            query: '영상-${i.toString().padLeft(6, '0')}',
          );
          samples.add(watch.elapsedMicroseconds);
          expect(found.length, 1);
        }
        samples.sort();
        metrics['searchP50Ms'] = samples[15] / 1000;
        metrics['searchP95Ms'] = samples[28] / 1000;
        final ids = rows.take(1000).map((r) => r['id'] as int).toList();
        await measure(
          'batch1000Ms',
          () => library.batchEdit(
            ids,
            rating: 4,
            setRating: true,
            tags: '대량, 검증',
          ),
        );
        expect(
          (await library.matching(
            const MediaCriteria(tags: '대량, 검증', minimumRating: 4),
          )).length,
          ids.length,
        );
        final backup = File(p.join(root.path, 'backup.json'));
        await measure('backupMs', () => library.exportTo(backup));
        await measure('restoreMs', () => library.restoreFrom(backup));
        expect((await library.items()).length, count);
        metrics['rssEnd'] = ProcessInfo.currentRss;
        metrics['maxRss'] = ProcessInfo.maxRss;
        final budgets = <String, num>{
          'coldScanMs': count <= 1000 ? 10000 : 60000,
          'warmScanMs': 15000,
          'searchP95Ms': 500,
          'batch1000Ms': 10000,
          'restoreMs': 30000,
        };
        metrics['budgetsMs'] = budgets;
        for (final entry in budgets.entries) {
          expect(metrics[entry.key], lessThan(entry.value), reason: entry.key);
        }
        metrics['passed'] = true;
      } finally {
        await Directory('build/verification').create(recursive: true);
        await File(
          'build/verification/load-$label.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(metrics));
        await library.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
    tags: 'load',
  );
}
