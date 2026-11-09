import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

int compareVersions(String a, String b) {
  List<int> parse(String s) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$').firstMatch(s);
    if (m == null) throw const FormatException('Invalid stable version');
    return [for (var i = 1; i <= 4; i++) int.parse(m.group(i) ?? '0')];
  }

  final x = parse(a), y = parse(b);
  for (var i = 0; i < 4; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

Future<Map<String, dynamic>> verifyManifest(
  List<int> bytes,
  String signature,
  String key,
) async {
  if (!await Ed25519().verify(
    bytes,
    signature: Signature(
      base64Decode(signature.trim()),
      publicKey: SimplePublicKey(base64Decode(key), type: KeyPairType.ed25519),
    ),
  )) {
    throw const FormatException('업데이트 서명을 확인할 수 없습니다.');
  }
  final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  compareVersions(manifest['version'] as String, '0.0.0');
  return manifest;
}

Uri downloadUri(String value) {
  final uri = Uri.parse(value);
  if (uri.scheme != 'https' ||
      uri.host != 'github.com' ||
      !uri.path.startsWith('/poyal/soft-vault/releases/download/') ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Invalid update URL');
  }
  return uri;
}

Future<void> verifyPackage(File file, Map<String, dynamic> asset) async {
  if (await file.length() != asset['size'] ||
      (await sha256.bind(file.openRead()).first).toString() !=
          asset['sha256']) {
    throw const FormatException('다운로드 파일이 손상되었습니다. 다시 다운로드하세요.');
  }
}
