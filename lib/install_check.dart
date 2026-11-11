import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import 'library.dart';
import 'media_tools.dart';
import 'file_jobs.dart';
import 'native_playback.dart';
import 'playback.dart';
import 'advanced_catalog.dart';
import 'nfo_service.dart';
import 'rule_runner.dart';
import 'privacy_lock.dart';
import 'playback_history.dart';
import 'library_filter.dart';
import 'metadata_exchange.dart';

/// Installer verification uses temporary data and never opens the user's catalog.
Future<void> verifyInstalledApp(
  String reportPath,
  String fixture, [
  String? codecs,
]) async {
  final report = <String, Object?>{
    'executable': Platform.resolvedExecutable,
    'passed': false,
  };
  final root = await Directory(
    await Directory.systemTemp.resolveSymbolicLinks(),
  ).createTemp('soft-vault-install-check-');
  Library? library;
  PrivacyLock? privacy;
  Player? player;
  var code = 1;
  try {
    // Exercise the bundled SQLite and Windows CNG paths on disposable data.
    final privacyPath = p.join(root.path, 'privacy.sqlite');
    privacy = PrivacyLock(privacyPath);
    if ((await privacy.status()).configured ||
        !await privacy.setPassword('install-check-only-2026')) {
      throw StateError('Installed privacy setup failed');
    }
    await privacy.close();
    privacy = PrivacyLock(privacyPath);
    if (!(await privacy.status()).enabled ||
        await privacy.authenticate('incorrect-password') ||
        !await privacy.authenticate('install-check-only-2026') ||
        await privacy.disable('incorrect-password') ||
        !await privacy.disable('install-check-only-2026') ||
        (await privacy.status()).enabled) {
      throw StateError('Installed privacy persistence/authentication failed');
    }
    report['privacyLock'] = {
      'setup': true,
      'restartPersistence': true,
      'rejectWrongPassword': true,
      'unlock': true,
      'authenticatedDisable': true,
    };
    final source = await Directory(p.join(root.path, 'source')).create();
    final destination = await Directory(
      p.join(root.path, 'destination'),
    ).create();
    await File(fixture).copy(p.join(source.path, 'fixture.mp4'));
    final dbPath = p.join(root.path, 'catalog.sqlite');
    library = await Library.open(dbPath);
    await library.connect(source.path);
    await library.connect(destination.path);
    final tools = MediaTools(
      library,
      Directory(p.join(root.path, 'thumbnails')),
      MediaTools.bundledBin(),
    );
    await tools.enrich();
    final item = (await library.items()).single;
    if ((item['duration'] as num) <= 0 ||
        !File(item['thumbnail'] as String).existsSync())
      throw StateError(
        'Bundled ffprobe/ffmpeg did not produce metadata and thumbnail',
      );
    await library.edit(item['id'] as int, {
      'rating': 5,
      'tags': 'installed-check',
    });
    final mediaId = item['id'] as int;
    await library.recordPlayback(mediaId, DateTime.now(), Duration.zero);
    final exchange = MetadataExchange(library);
    final request = await exchange.create();
    final response = jsonDecode(exchange.encode(request));
    response['videos'][0]['description'] = '설치 사본 AI 정보 교환';
    await exchange.apply(exchange.parse(jsonEncode(response), request), {
      mediaId: {'description'},
    });
    if ((await library.mediaById(mediaId))['description'] != '설치 사본 AI 정보 교환' ||
        (await library.mediaById(mediaId))['play_count'] != 1 ||
        (await library.items(
              filters: [
                LibraryFilter(playback: PlaybackFilter.played, rating: 5),
              ],
            )).length !=
            1 ||
        (await library.items(
          filters: [LibraryFilter(playback: PlaybackFilter.unplayed)],
        )).isNotEmpty) {
      throw StateError('Installed metadata exchange/playback filter failed');
    }
    report['metadataExchangeAndPlaybackHistory'] = true;
    await library.saveResume(
      mediaId,
      const Duration(seconds: 5),
      Duration(milliseconds: ((item['duration'] as num) * 1000).round()),
    );
    await library.saveBookmark(
      mediaId,
      const Duration(seconds: 3),
      title: '설치 검증 장면',
      note: '한글 메모\n둘째 줄',
    );
    await library.saveCollection(
      '설치 컬렉션',
      const MediaCriteria(tags: 'installed-check'),
    );
    final frame = await tools.frame(item, 3);
    await tools.setThumbnail(mediaId, frame);
    final animation = await tools.preview(item);
    if (!String.fromCharCodes(
      await File(animation).readAsBytes(),
    ).contains('ANIM'))
      throw StateError('Animated preview missing');
    final nfo = File(p.join(root.path, 'movie.nfo'));
    await NfoService(library).write(mediaId, nfo);
    await NfoService(
      library,
    ).apply(mediaId, await NfoService(library).read(nfo));
    await FileJobs(
      library,
    ).move([item['id'] as int], destination.path, forceCopy: true);
    await library.close();
    library = await Library.open(dbPath);
    final restored = (await library.items(query: 'installed-check')).single;
    if (restored['rating'] != 5 || restored['folder'] != destination.path)
      throw StateError('Catalog move/persistence failure');
    if (restored['resume_ms'] != 5000 ||
        restored['play_count'] != 1 ||
        (await library.mediaById(mediaId))['play_count'] != 1 ||
        restored['custom_thumbnail'] != 1 ||
        (await library.bookmarks(mediaId)).single['note'] != '한글 메모\n둘째 줄' ||
        (await library.matching(
              MediaCriteria.decode(
                (await library.collections()).single['criteria'] as String,
              ),
            )).length !=
            1)
      throw StateError('Extended metadata persistence failure');
    await library.saveMoveRule(
      '설치 규칙',
      MediaCriteria(folder: destination.path, tags: 'installed-check'),
      source.path,
    );
    final runner = RuleRunner(library, FileJobs(library));
    await runner.run((await library.moveRules()).single);
    final finalItem = await library.mediaById(mediaId);
    if (finalItem['folder'] != source.path)
      throw StateError('Installed rule move failed');
    report['extendedFeatures'] = {
      'resume': true,
      'bookmarks': true,
      'collections': true,
      'customThumbnail': true,
      'animatedPreview': true,
      'nfo': true,
      'ruleMove': true,
    };
    player = Player();
    final controller = VideoController(player);
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Video(controller: controller, controls: NoVideoControls),
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    final playback = Playback(NativePlayback(player));
    await playback.open(
      finalItem['path'] as String,
      start: const Duration(seconds: 5),
    );
    await controller.waitUntilFirstFrameRendered.timeout(
      const Duration(seconds: 20),
    );
    if (player.state.duration == Duration.zero)
      await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (player.state.position.inSeconds < 5)
      throw StateError('Installed resume failed');
    if (player.state.volume != 0 || player.state.position <= Duration.zero)
      throw StateError('Native playback did not start silently');
    await playback.panic();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!await windowManager.isMinimized())
      throw StateError('Native minimization failed');
    await windowManager.restore();
    if (player.state.volume != 0)
      throw StateError('Volume changed after restoration');
    if (codecs != null) {
      final results = <Map<String, Object?>>[];
      final files = await Directory(codecs)
          .list()
          .where(
            (file) =>
                file is File &&
                [
                  '.mp4',
                  '.mkv',
                  '.avi',
                  '.mov',
                  '.webm',
                  '.wmv',
                  '.ts',
                ].contains(p.extension(file.path)),
          )
          .toList();
      if (files.isEmpty) throw StateError('No codec fixtures');
      for (final file in files) {
        await playback.open(file.path);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (player.state.position <= Duration.zero ||
            (player.state.videoParams.dw ?? 0) <= 0 ||
            player.state.volume != 0) {
          throw StateError('Installed codec failed: ${p.basename(file.path)}');
        }
        results.add({
          'file': p.basename(file.path),
          'width': player.state.videoParams.dw,
          'height': player.state.videoParams.dh,
          'volume': player.state.volume,
        });
      }
      report['codecs'] = results;
    }
    report.addAll({
      'passed': true,
      'database': true,
      'verifiedCopyMove': true,
      'ffprobe': true,
      'thumbnail': true,
      'nativePlayback': true,
      'volume': player.state.volume,
      'nativeMinimizeRestore': true,
    });
    code = 0;
  } catch (e, stack) {
    report['error'] = '$e';
    report['stack'] = '$stack';
  } finally {
    await player?.dispose();
    await library?.close();
    await privacy?.close();
    await File(reportPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
      flush: true,
    );
    await root.delete(recursive: true);
  }
  exit(code);
}
