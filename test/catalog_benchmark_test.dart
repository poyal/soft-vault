import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';
import 'package:soft_vault/advanced_catalog.dart';

void main() {
  test(
    'LOAD-02 50000 catalog records search, filter, duplicates and persistence',
    () async {
      final root = await Directory(
        await Directory.systemTemp.resolveSymbolicLinks(),
      ).createTemp('vault-catalog-load-');
      final library = await Library.open(p.join(root.path, 'db.sqlite'));
      final report = <String, Object?>{
        'records': 50000,
        'mode': 'SQLite synthetic catalog; no video decoding',
        'passed': false,
      };
      Future<T> measure<T>(String key, Future<T> Function() work) async {
        final clock = Stopwatch()..start();
        final value = await work();
        report[key] = clock.elapsedMilliseconds;
        return value;
      }

      try {
        await measure(
          'seedMs',
          () => library.db.transaction((tx) async {
            final batch = tx.batch();
            for (var i = 0; i < 50000; i++) {
              batch.insert('media', {
                'path': p.join(root.path, 'media-$i.mp4'),
                'folder': root.path,
                'title': 'media-${i.toString().padLeft(6, '0')}',
                'type': 'video',
                'added': i,
                'rating': i % 5 + 1,
                'tags': i % 10 == 0 ? 'selected' : '',
                'fingerprint': 'hash-${i ~/ 2}',
                'size': i ~/ 2,
                'online': 0,
              });
            }
            await batch.commit(noResult: true);
          }),
        );
        expect((await measure('listMs', () => library.items())).length, 50000);
        final times = <int>[];
        for (var i = 0; i < 40; i++) {
          final clock = Stopwatch()..start();
          final result = await library.items(
            query: 'media-${(i * 1000).toString().padLeft(6, '0')}',
            limit: 3,
          );
          times.add(clock.elapsedMicroseconds);
          expect(result.length, 1);
        }
        times.sort();
        report['searchP50Ms'] = times[20] / 1000;
        report['searchP95Ms'] = times[37] / 1000;
        expect(
          (await measure(
            'collectionMs',
            () => library.matching(const MediaCriteria(tags: 'selected')),
          )).length,
          5000,
        );
        expect(
          (await measure(
            'duplicatesMs',
            () => library.duplicateGroups(),
          )).length,
          25000,
        );
        final backup = File(p.join(root.path, 'large.json'));
        await measure('backupMs', () => library.exportTo(backup));
        report['backupBytes'] = await backup.length();
        report['rss'] = ProcessInfo.currentRss;
        report['maxRss'] = ProcessInfo.maxRss;
        final budgets = <String, num>{
          'searchP95Ms': 500,
          'listMs': 5000,
          'collectionMs': 5000,
          'duplicatesMs': 5000,
          'backupMs': 10000,
        };
        report['budgetsMs'] = budgets;
        for (final budget in budgets.entries) {
          expect(
            report[budget.key],
            lessThan(budget.value),
            reason: budget.key,
          );
        }
        expect(ProcessInfo.currentRss, lessThan(1024 * 1024 * 1024));
        report['passed'] = true;
      } finally {
        await Directory('build/verification').create(recursive: true);
        await File(
          'build/verification/catalog-50000.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
        await library.close();
        await root.delete(recursive: true);
      }
    },
    tags: 'load',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
