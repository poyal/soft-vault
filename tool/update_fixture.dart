import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length == 2 && args[0] == '--update-ready') {
    if (await File(
      '${File(Platform.resolvedExecutable).parent.path}/fail',
    ).exists())
      exit(1);
    await File(args[1]).writeAsString('ready', flush: true);
  }
}
