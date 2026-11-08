import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Bind runtime sources, tests and platform configuration to a verification run.
Future<void> main(List<String> arguments) async {
  final paths = <String>{};
  for (final path in [
    'lib',
    'test',
    'integration_test',
    'scripts',
    'tool',
    'windows/runner',
    'windows/CMakeLists.txt',
    'macos/Runner',
    'macos/Runner.xcodeproj/project.pbxproj',
    'macos/Flutter/Flutter-Debug.xcconfig',
    'macos/Flutter/Flutter-Release.xcconfig',
    'macos/Podfile',
    'macos/Podfile.lock',
    'pubspec.yaml',
    'pubspec.lock',
    'design/assets/app-icon.png',
  ]) {
    if (await File(path).exists()) {
      paths.add(path);
    } else if (await Directory(path).exists()) {
      await for (final entry in Directory(
        path,
      ).list(recursive: true, followLinks: false)) {
        if (entry is File && !p.basename(entry.path).startsWith('.')) {
          paths.add(p.split(entry.path).join('/'));
        }
      }
    } else {
      throw StateError('Missing source: $path');
    }
  }
  final entries = <Map<String, String>>[];
  for (final path in paths.toList()..sort()) {
    List<int> bytes = await File(path).readAsBytes();
    if (!['.png', '.jpg', '.jpeg', '.ico'].contains(p.extension(path))) {
      // Git and Windows checkouts may differ only by newline encoding.
      bytes = utf8.encode(utf8.decode(bytes).replaceAll('\r\n', '\n'));
    }
    entries.add({'path': path, 'sha256': sha256.convert(bytes).toString()});
  }
  final fingerprint = sha256
      .convert(utf8.encode(jsonEncode(entries)))
      .toString();
  final output = const JsonEncoder.withIndent('  ').convert({
    'sourceSHA256': fingerprint,
    'textNewlines': 'LF',
    'files': entries,
  });
  if (arguments.isEmpty) {
    stdout.writeln(output);
  } else {
    await File(arguments.single).writeAsString('$output\n');
    stdout.writeln(fingerprint);
  }
}
