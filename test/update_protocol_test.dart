import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:soft_vault/update_protocol.dart';

void main() {
  test('package rejects wrong size and same-size corruption', () async {
    final root = await Directory.systemTemp.createTemp('update-package-test-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/package.zip');
    final bytes = utf8.encode('verified package');
    await file.writeAsBytes(bytes);
    final asset = <String, dynamic>{
      'size': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
    };
    await verifyPackage(file, asset);
    await file.writeAsBytes([...bytes, 0]);
    await expectLater(verifyPackage(file, asset), throwsFormatException);
    await file.writeAsBytes([bytes.first ^ 1, ...bytes.skip(1)]);
    await expectLater(verifyPackage(file, asset), throwsFormatException);
  });
  test('stable semantic versions and build numbers', () {
    expect(compareVersions('v1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('1.0.0+2', '1.0.0+1'), 0);
    expect(compareVersions('v1.0.0', '1.0.0'), 0);
    expect(() => compareVersions('1.0.0-beta', '1.0.0'), throwsFormatException);
  });
  test('only repository release URLs', () {
    expect(
      () => downloadUri('https://evil.example/payload'),
      throwsFormatException,
    );
    expect(
      () => downloadUri(
        'http://github.com/poyal/soft-vault/releases/download/v1/a',
      ),
      throwsFormatException,
    );
    expect(
      downloadUri(
        'https://github.com/poyal/soft-vault/releases/download/v1/a',
      ).host,
      'github.com',
    );
  });
  test('manifest rejects modified bytes and wrong signing key', () async {
    final ed = Ed25519(),
        bytes = utf8.encode('{"version":"1.2.3","platforms":{}}');
    final key = await ed.newKeyPair();
    final public = base64Encode((await key.extractPublicKey()).bytes);
    final signature = base64Encode((await ed.sign(bytes, keyPair: key)).bytes);
    expect(
      (await verifyManifest(bytes, signature, public))['version'],
      '1.2.3',
    );
    await expectLater(
      verifyManifest([...bytes, 32], signature, public),
      throwsFormatException,
    );
    final other = await ed.newKeyPair();
    await expectLater(
      verifyManifest(
        bytes,
        signature,
        base64Encode((await other.extractPublicKey()).bytes),
      ),
      throwsFormatException,
    );
  });
}
