import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/app_updater.dart';

// Keep production repository-URL validation, but serve deterministic bytes locally.
class _LocalUpdates extends HttpOverrides {
  final Uri base;
  _LocalUpdates(this.base);
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _MappedClient(super.createHttpClient(context), base);
}

class _MappedClient implements HttpClient {
  final HttpClient client;
  final Uri base;
  _MappedClient(this.client, this.base);
  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      client.getUrl(base.replace(path: url.path));
  @override
  void close({bool force = false}) => client.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'signed check, corrupt download, retry and persisted preferences',
    () async {
      final root = await Directory.systemTemp.createTemp('updater-flow-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        await root.delete(recursive: true);
      });
      final payload = utf8.encode('release candidate zip fixture');
      final key = await Ed25519().newKeyPair();
      const prefix =
          'https://github.com/poyal/soft-vault/releases/download/v0.2.0';
      final asset = {
        'url': '$prefix/package.zip',
        'size': payload.length,
        'sha256': sha256.convert(payload).toString(),
      };
      final manifest = utf8.encode(
        jsonEncode({
          'version': '0.2.0',
          'platforms': {'windows-x64': asset, 'macos-arm64': asset},
        }),
      );
      final signature = base64Encode(
        (await Ed25519().sign(manifest, keyPair: key)).bytes,
      );
      var corrupt = true, serverFailure = false, latest = 'v0.2.0';
      server.listen((request) async {
        final response = request.response;
        if (serverFailure) {
          response.statusCode = 503;
        } else if (request.uri.path.endsWith('/latest')) {
          response.write(
            jsonEncode({
              'tag_name': latest,
              'draft': false,
              'prerelease': false,
              'body': 'Verified changes',
              'assets': [
                for (final name in ['update.json', 'update.json.sig'])
                  {'name': name, 'browser_download_url': '$prefix/$name'},
              ],
            }),
          );
        } else if (request.uri.path.endsWith('/update.json.sig')) {
          response.write(signature);
        } else if (request.uri.path.endsWith('/update.json')) {
          response.add(manifest);
        } else if (request.uri.path.endsWith('/package.zip')) {
          response.add(
            corrupt ? [payload.first ^ 1, ...payload.skip(1)] : payload,
          );
        } else {
          response.statusCode = 404;
        }
        await response.close();
      });
      await HttpOverrides.runWithHttpOverrides(() async {
        final updater = AppUpdater(root)..automatic = false;
        addTearDown(updater.dispose);
        await updater.save();
        await updater.initialize();
        expect(updater.automatic, isFalse);
        updater.current = '0.1.0';
        updater.config['publicKey'] = base64Encode(
          (await key.extractPublicKey()).bytes,
        );
        await updater.check();
        expect(updater.release?['version'], '0.2.0');
        expect(updater.working, isFalse);
        expect(updater.ready, isFalse);
        await updater.download();
        expect(updater.ready, isFalse);
        expect(updater.message, contains('중단'));
        corrupt = false;
        await updater.download();
        expect(updater.ready, isTrue);
        expect(await updater.package.readAsBytes(), payload);
        serverFailure = true;
        await updater.check();
        expect(updater.working, isFalse);
        expect(updater.message, contains('확인 실패'));
        serverFailure = false;
        latest = 'v0.1.0';
        await updater.check();
        expect(updater.release, isNull);
        expect(updater.ready, isFalse);
        expect(updater.message, '최신 버전입니다.');
        final persisted = jsonDecode(await updater.preferences.readAsString());
        expect(persisted['automatic'], isFalse);
        expect(DateTime.tryParse(persisted['lastCheck']), isNotNull);
      }, _LocalUpdates(Uri.parse('http://127.0.0.1:${server.port}')));
    },
  );
}
