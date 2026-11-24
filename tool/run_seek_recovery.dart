// Run baseline and candidate sequentially on one desktop. Each executable is
// a Release build of seek_recovery_probe.dart from the corresponding source.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.length != 5) {
    throw ArgumentError(
      'Expected baseline-exe candidate-exe media-dir result-dir rounds-per-file',
    );
  }
  final rounds = int.parse(args[4]);
  if (rounds < 1) throw ArgumentError('At least one round is required.');
  final directory = await Directory(
    p.absolute(args[3]),
  ).create(recursive: true);
  const fixtures = ['1080p60', 'long-gop', 'vfr', '4k60'];
  for (var i = 0; i < fixtures.length; i++) {
    final name = fixtures[i];
    for (final index in i.isEven ? [0, 1] : [1, 0]) {
      final version = index == 0 ? 'baseline' : 'candidate';
      final path = p.join(directory.path, '$version-$name');
      final file = File('$path.json');
      if (await file.exists() &&
          jsonDecode(await file.readAsString())['complete'] == true) {
        throw StateError('Existing completed run: $path');
      }
      final process = await Process.start(p.absolute(args[index]), [
        p.absolute(args[2], '$name.mkv'),
        file.path,
        args[4],
        'taps,hold,alternate,clicks,drag',
      ]);
      final log = File('$path.log').openWrite();
      final streams = Future.wait([
        process.stdout.forEach(log.add),
        process.stderr.forEach(log.add),
      ]);
      final status = await process.exitCode.timeout(
        Duration(seconds: rounds * 75 + 90),
        onTimeout: () async {
          process.kill(ProcessSignal.sigkill);
          await process.exitCode;
          return -1;
        },
      );
      await streams;
      await log.close();
      if (status != 0 ||
          !await file.exists() ||
          jsonDecode(await file.readAsString())['complete'] != true) {
        throw StateError('$version $name failed ($status), see $path');
      }
      stdout.writeln('Completed $version $name');
    }
  }
}
