import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/main.dart';
import 'package:soft_vault/playback.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled native decoder container codec and subtitle matrix', (
    tester,
  ) async {
    const root = String.fromEnvironment('CODEC_FIXTURES');
    expect(root.isNotEmpty && Directory(root).existsSync(), isTrue);
    MediaKit.ensureInitialized();
    await windowManager.ensureInitialized();
    final player = Player();
    final playback = Playback(NativePlayback(player));
    final results = <Map<String, Object?>>[];
    final errors = <String>[];
    final subscription = player.stream.error.listen(errors.add);
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Video(
              controller: VideoController(player),
              controls: NoVideoControls,
            ),
          ),
        ),
      );
      final files =
          Directory(root)
              .listSync()
              .whereType<File>()
              .where(
                (file) => [
                  '.mp4',
                  '.mkv',
                  '.avi',
                  '.mov',
                  '.ts',
                  '.wmv',
                  '.webm',
                ].contains(p.extension(file.path)),
              )
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      expect(files.length, greaterThanOrEqualTo(11));
      for (final file in files) {
        errors.clear();
        await playback.open(file.path);
        var decoded = false;
        for (var attempt = 0; attempt < 100; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
          if ((player.state.videoParams.dw ?? 0) > 0 &&
              player.state.position > Duration.zero) {
            decoded = true;
            break;
          }
        }
        final params = player.state.videoParams;
        final record = <String, Object?>{
          'file': p.basename(file.path),
          'decoded': decoded,
          'width': params.dw,
          'height': params.dh,
          'pixelFormat': params.pixelformat,
          'primaries': params.primaries,
          'gamma': params.gamma,
          'audioTracks': player.state.tracks.audio
              .where((track) => track.id != 'auto' && track.id != 'no')
              .length,
          'subtitleTracks': player.state.tracks.subtitle
              .where((track) => track.id != 'auto' && track.id != 'no')
              .length,
          'volume': player.state.volume,
          'errors': List<String>.from(errors),
        };
        results.add(record);
        expect(decoded, isTrue, reason: '${file.path}: $errors');
        expect(player.state.volume, 0);
        if (p.basename(file.path) == 'hevc4k-hdr.mkv') {
          expect(params.dw, 3840);
          expect(params.dh, 2160);
        } else if (p.basename(file.path) != 'vc1.wmv') {
          expect(
            record['audioTracks'] as int,
            greaterThan(0),
            reason: p.basename(file.path),
          );
        }
        if (p.basename(file.path) == 'embedded-subtitle.mkv')
          expect(record['subtitleTracks'] as int, greaterThan(0));
        await player.pause();
      }
      for (final extension in ['srt', 'ass', 'smi']) {
        await playback.open(p.join(root, 'h264-aac.mp4'));
        await player.pause();
        await player.setSubtitleTrack(
          SubtitleTrack.uri(p.join(root, 'sample.$extension')),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(player.state.track.subtitle.id, contains('sample.$extension'));
      }
      await (player.platform as NativePlayer).setProperty('hwdec', 'no');
      await playback.open(p.join(root, 'hevc10-eac3.mkv'));
      await tester.pump(const Duration(seconds: 1));
      expect(player.state.position, greaterThan(Duration.zero));
      expect(tester.takeException(), isNull);
    } finally {
      await Directory('build/e2e').create(recursive: true);
      await File(
        'build/e2e/codec-results.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      await subscription.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      await player.dispose();
    }
  });
}
