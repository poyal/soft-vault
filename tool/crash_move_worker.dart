import 'dart:io';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/file_jobs.dart';

Future<void> main(List<String> args) async {
  if (args.length != 4) {
    stderr.writeln('Usage: catalog mediaId destination phase');
    exit(64);
  }
  final library = await Library.open(args[0]);
  await FileJobs(
    library,
    checkpoint: (phase) {
      if (phase == args[3]) exit(93);
    },
  ).move([int.parse(args[1])], args[2], forceCopy: true);
  await library.close();
  exit(0);
}
