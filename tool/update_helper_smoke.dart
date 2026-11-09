import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  final suffix = Platform.isWindows ? '.exe' : '';
  final platform = Platform.isWindows ? 'windows-x64' : 'macos-arm64';
  final prefix = Platform.isWindows
      ? 'SoftVault-Windows/app'
      : 'SoftVault-macOS-arm64/Soft Vault.app';
  final executable = Platform.isWindows
      ? 'soft_vault.exe'
      : 'Contents/MacOS/Soft Vault';
  await Directory('build/update-smoke').create(recursive: true);
  for (final scenario in [
    'install',
    'rollback',
    'invalid-signature',
    'corrupt-package',
    'unsafe-archive',
  ]) {
    final fail = scenario != 'install';
    final area = await Directory('build/update-smoke').createTemp('case-');
    final base = p.absolute(area.path), target = Directory(p.join(base, 'app'));
    final data = Directory(p.join(base, 'data')),
        root = Directory(p.join(base, 'data', 'updates'));
    await target.create();
    await root.create(recursive: true);
    final fixture = await File('build/update_fixture$suffix').readAsBytes();
    final oldExe = File(p.join(target.path, executable));
    await oldExe.parent.create(recursive: true);
    await oldExe.writeAsBytes(fixture);
    if (!Platform.isWindows) {
      final chmod = await Process.run('/bin/chmod', ['755', oldExe.path]);
      if (chmod.exitCode != 0) throw StateError('Fixture permissions failed');
    }
    await File(p.join(target.path, 'old-marker')).writeAsString('old');
    await File(p.join(data.path, 'vault.sqlite')).writeAsString('catalog');
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes('$prefix/$executable', fixture)..mode = 0x1ed,
      );
    if (scenario == 'rollback')
      archive.addFile(
        ArchiveFile.string(
          '$prefix/${p.posix.dirname(executable)}/fail',
          'fail',
        ),
      );
    if (scenario == 'unsafe-archive') {
      archive.addFile(ArchiveFile.string('$prefix/../escaped-marker', 'bad'));
    }
    final zip = ZipEncoder().encode(archive);
    await File(p.join(root.path, 'package.zip')).writeAsBytes(zip);
    final manifest = utf8.encode(
      jsonEncode({
        'version': '0.2.0',
        'platforms': {
          platform: {
            'size': zip.length,
            'sha256': sha256.convert(zip).toString(),
          },
        },
      }),
    );
    final ed = Ed25519(), key = await Ed25519().newKeyPair();
    await File(p.join(root.path, 'update.json')).writeAsBytes(manifest);
    await File(p.join(root.path, 'update.json.sig')).writeAsString(
      base64Encode((await ed.sign(manifest, keyPair: key)).bytes),
    );
    if (scenario == 'invalid-signature') {
      await File(
        p.join(root.path, 'update.json'),
      ).writeAsBytes([...manifest, 32]);
    }
    if (scenario == 'corrupt-package') {
      await File(
        p.join(root.path, 'package.zip'),
      ).writeAsBytes([zip.first ^ 1, ...zip.skip(1)]);
    }
    final result =
        await Process.run(p.absolute('build/soft_vault_updater$suffix'), [
          root.path,
          target.path,
          data.path,
          '99999999',
          base64Encode((await key.extractPublicKey()).bytes),
        ]).timeout(const Duration(seconds: 40));
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    final state = jsonDecode(
      await File(p.join(root.path, 'transaction.json')).readAsString(),
    )['state'];
    if (state != (fail ? 'rolledBack' : 'complete'))
      throw StateError('Unexpected state $state');
    if (await File(p.join(data.path, 'vault.sqlite')).readAsString() !=
        'catalog')
      throw StateError('Catalog changed');
    if (await File(p.join(target.path, 'old-marker')).exists() != fail)
      throw StateError('Wrong app restored');
    if (scenario == 'unsafe-archive' &&
        (await File(p.join(base, 'escaped-marker')).exists() ||
            await File(
              p.join('${target.path}.update-stage', 'escaped-marker'),
            ).exists())) {
      throw StateError('Archive escaped its destination');
    }
    if (fail && scenario != 'rollback') {
      final failure = await File(
        p.join(root.path, 'failure-type.txt'),
      ).readAsString();
      if (failure != 'FormatException')
        throw StateError('Unexpected rejection: $failure');
    }
    stdout.writeln('$scenario: PASS');
  }
}
