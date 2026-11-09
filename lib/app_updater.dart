import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'update_protocol.dart';

class AppUpdater extends ChangeNotifier {
  static AppUpdater? instance;
  final Directory root;
  AppUpdater(this.root);
  String current = '', message = '', notes = '';
  DateTime? lastCheck;
  bool automatic = true, working = false, ready = false;
  double? progress;
  Map<String, dynamic>? release, asset;
  Map<String, dynamic> config = {};
  HttpClient? _client;
  File get package => File(p.join(root.path, 'package.zip'));
  File get preferences => File(p.join(root.path, 'preferences.json'));
  Future<void> initialize() async {
    await root.create(recursive: true);
    config = jsonDecode(
      await rootBundle.loadString('assets/update-config.json'),
    );
    current = config['version'];
    if (await preferences.exists()) {
      try {
        final prefs = jsonDecode(await preferences.readAsString());
        automatic = prefs['automatic'] != false;
        lastCheck = DateTime.tryParse(prefs['lastCheck'] ?? '');
      } catch (_) {
        /* Damaged preferences use safe defaults. */
      }
    }
    if (automatic &&
        (lastCheck == null ||
            DateTime.now().difference(lastCheck!).inHours >= 24))
      unawaited(check());
  }

  Future<void> setAutomatic(bool value) async {
    automatic = value;
    await save();
    notifyListeners();
  }

  Future<void> save() => preferences
      .writeAsString(
        jsonEncode({
          'automatic': automatic,
          'lastCheck': lastCheck?.toIso8601String(),
        }),
      )
      .then((_) {});
  Future<List<int>> get(Uri uri, {int limit = 2097152}) async {
    final request = await _client!
        .getUrl(uri)
        .timeout(const Duration(seconds: 20));
    request.headers.set('User-Agent', 'SoftVault-Updater');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != 200)
      throw HttpException('업데이트 서버 응답: ${response.statusCode}');
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      bytes.addAll(chunk);
      if (bytes.length > limit)
        throw const FormatException('Response too large');
    }
    return bytes;
  }

  Future<void> check() async {
    if (working) return;
    working = true;
    message = '업데이트 확인 중';
    notifyListeners();
    _client = HttpClient();
    try {
      lastCheck = DateTime.now();
      await save();
      final latest = jsonDecode(
        utf8.decode(
          await get(
            Uri.parse(
              'https://api.github.com/repos/poyal/soft-vault/releases/latest',
            ),
          ),
        ),
      );
      if (latest['draft'] == true || latest['prerelease'] == true)
        throw const FormatException('정식 릴리즈가 아닙니다.');
      if (compareVersions(latest['tag_name'], current) <= 0) {
        message = '최신 버전입니다.';
        release = null;
        ready = false;
        return;
      }
      final assets = latest['assets'] as List;
      String url(String name) =>
          assets.singleWhere((a) => a['name'] == name)['browser_download_url'];
      final bytes = await get(downloadUri(url('update.json')));
      final signature = utf8.decode(
        await get(downloadUri(url('update.json.sig'))),
      );
      final manifest = await verifyManifest(
        bytes,
        signature,
        config['publicKey'],
      );
      if (compareVersions(manifest['version'], latest['tag_name']) != 0)
        throw const FormatException('릴리즈 버전 불일치');
      final nextAsset =
          manifest['platforms'][Platform.isWindows
                  ? 'windows-x64'
                  : 'macos-arm64']
              as Map<String, dynamic>;
      downloadUri(nextAsset['url']);
      release = manifest;
      asset = nextAsset;
      notes = latest['body'] ?? '';
      ready = false;
      await File(p.join(root.path, 'update.json')).writeAsBytes(bytes);
      await File(p.join(root.path, 'update.json.sig')).writeAsString(signature);
      message = '새 버전 ${manifest['version']}을 사용할 수 있습니다.';
    } catch (_) {
      message = '업데이트 확인 실패. 네트워크와 릴리즈 파일을 확인한 뒤 다시 시도하세요.';
    } finally {
      _client?.close(force: true);
      _client = null;
      working = false;
      notifyListeners();
    }
  }

  void cancel() {
    _client?.close(force: true);
  }

  Future<void> download() async {
    if (working || asset == null) return;
    working = true;
    ready = false;
    progress = 0;
    message = '다운로드 중';
    notifyListeners();
    _client = HttpClient();
    IOSink? sink;
    try {
      final response =
          await (await _client!
                  .getUrl(downloadUri(asset!['url']))
                  .timeout(const Duration(seconds: 20)))
              .close()
              .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200)
        throw const HttpException('Download failed');
      sink = package.openWrite();
      var count = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        count += chunk.length;
        if (count > (asset!['size'] as int))
          throw const FormatException('Size exceeded');
        sink.add(chunk);
        progress = count / (asset!['size'] as int);
        notifyListeners();
      }
      await sink.flush();
      await sink.close();
      sink = null;
      await verifyPackage(package, asset!);
      ready = true;
      message = '설치 준비 완료';
    } catch (_) {
      message = '다운로드가 중단되었습니다. 다시 시도할 수 있습니다.';
    } finally {
      await sink?.close();
      _client?.close(force: true);
      _client = null;
      working = false;
      progress = null;
      notifyListeners();
    }
  }

  Future<void> launchHelper(String dataPath) async {
    if (!ready || working || asset == null) throw StateError('다운로드를 먼저 완료하세요.');
    await verifyPackage(package, asset!);
    final executable = File(Platform.resolvedExecutable);
    final target = Platform.isWindows
        ? executable.parent.path
        : p.dirname(p.dirname(executable.parent.path));
    final helper = Platform.isWindows
        ? p.join(target, 'tools', 'soft_vault_updater.exe')
        : p.join(target, 'Contents', 'MacOS', 'tools', 'soft_vault_updater');
    final copy = await File(helper).copy(p.join(root.path, p.basename(helper)));
    if (!Platform.isWindows)
      await Process.run('/bin/chmod', ['700', copy.path]);
    final probe = File(p.join(p.dirname(target), '.soft-vault-write-$pid'));
    await probe.writeAsString('');
    await probe.delete();
    await Process.start(copy.path, [
      root.path,
      target,
      dataPath,
      '$pid',
      config['publicKey'],
    ], mode: ProcessStartMode.detached);
  }
}
