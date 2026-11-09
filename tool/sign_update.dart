import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  final ed = Ed25519();
  if (args.first == 'keygen') {
    final key = await ed.newKeyPair();
    final target = File(args[1]);
    if (await target.exists()) throw StateError('Key already exists');
    await target.parent.create(recursive: true);
    await target.writeAsString(
      base64Encode(await key.extractPrivateKeyBytes()),
      flush: true,
    );
    final version = RegExp(
      r'^version: (.+)$',
      multiLine: true,
    ).firstMatch(await File('pubspec.yaml').readAsString())!.group(1)!;
    await File('assets/update-config.json').writeAsString(
      jsonEncode({
        'version': version,
        'publicKey': base64Encode((await key.extractPublicKey()).bytes),
      }),
    );
    return;
  }
  final file = File(args[1]);
  final key = await ed.newKeyPairFromSeed(
    base64Decode(
      await File(Platform.environment['SOFT_VAULT_UPDATE_KEY']!).readAsString(),
    ),
  );
  final config = jsonDecode(
    await File('assets/update-config.json').readAsString(),
  );
  if (base64Encode((await key.extractPublicKey()).bytes) !=
      config['publicKey']) {
    throw StateError(
      'Signing key does not match the public key bundled in the app',
    );
  }
  final signature = await ed.sign(await file.readAsBytes(), keyPair: key);
  await File('${file.path}.sig').writeAsString(base64Encode(signature.bytes));
}
