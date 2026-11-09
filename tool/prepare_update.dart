import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

Future<void> main(List<String> args) async {
  final version = RegExp(
    r'^version: (.+)$',
    multiLine: true,
  ).firstMatch(await File('pubspec.yaml').readAsString())!.group(1)!;
  final configFile = File('assets/update-config.json');
  final config = jsonDecode(await configFile.readAsString());
  if (args.isNotEmpty && args.first == '--check') {
    final built = jsonDecode(await File(args[1]).readAsString());
    if (config['version'] != version ||
        built['version'] != version ||
        built['publicKey'] != config['publicKey']) {
      throw StateError(
        'Prepare update configuration before rebuilding the app',
      );
    }
    return;
  }
  if (args.contains('--prepare')) {
    config['version'] = version;
    await configFile.writeAsString(jsonEncode(config));
    return;
  }
  final tag = 'v${version.split('+').first}';
  final requested = args
      .where((arg) => arg.startsWith('--platform='))
      .map((arg) => arg.substring(11))
      .toSet();
  if (requested.isEmpty ||
      requested.any(
        (platform) => !['windows-x64', 'macos-arm64'].contains(platform),
      )) {
    throw ArgumentError(
      'Specify verified platforms with --platform=windows-x64 and/or --platform=macos-arm64',
    );
  }
  final platforms = <String, dynamic>{};
  for (final entry in {
    'windows-x64': 'SoftVault-Windows.zip',
    'macos-arm64': 'SoftVault-macOS-arm64.zip',
  }.entries) {
    if (!requested.contains(entry.key)) continue;
    final file = File('build/package/${entry.value}');
    // Installation media are EXE/DMG; the existing helper reads these ZIP bytes
    // under a dedicated extension, without changing the archive layout.
    final updateName = entry.value.replaceAll('.zip', '.svupdate');
    await file.copy('build/package/$updateName');
    platforms[entry.key] = {
      'url':
          'https://github.com/poyal/soft-vault/releases/download/$tag/$updateName',
      'size': await file.length(),
      'sha256': (await sha256.bind(file.openRead()).first).toString(),
    };
  }
  await File('build/package/update.json').writeAsString(
    jsonEncode({'version': version.split('+').first, 'platforms': platforms}),
  );
}
