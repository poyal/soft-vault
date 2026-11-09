import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  final exe = p.absolute(args[0]), fixture = p.absolute(args[1]);
  final root = await Directory('build/shutdown-probes').create(recursive: true);
  final results = <Map<String, Object?>>[];
  for (final mode
      in args.length > 2 ? args[2].split(',') : ['normal', 'repeated']) {
    for (final state
        in args.length > 3
            ? args[3].split(',')
            : ['idle', 'playing', 'paused']) {
      for (var i = 0; i < (args.length > 4 ? int.parse(args[4]) : 3); i++) {
        final dir = await root.createTemp('$mode-$state-');
        final process = await Process.start(exe, [
          p.absolute(dir.path),
          fixture,
          mode,
          state,
        ], workingDirectory: p.dirname(exe));
        final output = process.stdout.transform(utf8.decoder).join(),
            error = process.stderr.transform(utf8.decoder).join();
        var timedOut = false;
        final code = await process.exitCode.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            timedOut = true;
            process.kill();
            return -1;
          },
        );
        final end = DateTime.now().microsecondsSinceEpoch;
        if (timedOut) await process.exitCode;
        await File(
          '${dir.path}/process.log',
        ).writeAsString('${await output}\n${await error}');
        final file = File('${dir.path}/trace.jsonl');
        final trace = await file.exists()
            ? (await file.readAsLines())
                  .map((s) => jsonDecode(s) as Map<String, dynamic>)
                  .toList()
            : <Map<String, dynamic>>[];
        final start =
            trace
                    .where((e) => e['phase'] == 'close_requested')
                    .firstOrNull?['us']
                as int?;
        final result = <String, Object?>{
          'mode': mode,
          'state': state,
          'run': i,
          'exitCode': code,
          'timeout': timedOut,
          'directory': dir.path,
          'closeMs': start == null ? null : (end - start) / 1000,
          'closeBudgetMs': 2000,
          'withinCloseBudget': start != null && (end - start) <= 2000000,
          'stages': [
            for (final event in trace)
              {
                'phase': event['phase'],
                'ms': start == null
                    ? null
                    : ((event['us'] as int) - start) / 1000,
              },
          ],
        };
        if (code == 0 && !timedOut) {
          final db = await databaseFactoryFfi.openDatabase(
            p.absolute(dir.path, 'catalog.sqlite'),
            options: OpenDatabaseOptions(readOnly: true),
          );
          final saved = (await db.query('media')).single['resume_ms'] as int;
          await db.close();
          final expected = jsonDecode(
            await File('${dir.path}/expected.json').readAsString(),
          );
          final position = expected['positionMs'] as int;
          result['savedPositionMs'] = saved;
          result['positionPreserved'] = state == 'idle'
              ? saved == 0
              : position > 0 && saved >= position && saved <= position + 1500;
        }
        results.add(result);
        stdout.writeln(jsonEncode(result));
        await File(
          '${root.path}/${args.length > 5 ? args[5] : 'results'}.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      }
    }
  }
  if (results.any(
    (r) =>
        r['exitCode'] != 0 ||
        r['timeout'] == true ||
        r['withinCloseBudget'] != true ||
        r['positionPreserved'] != true,
  )) {
    exitCode = 1;
  }
}
