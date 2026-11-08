import 'support/native_surface.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/playback.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native playback starts silent and panic survives restoration', (
    tester,
  ) async {
    const fixture = String.fromEnvironment('VIDEO_FIXTURE');
    expect(
      fixture.isNotEmpty && File(fixture).existsSync(),
      isTrue,
      reason: 'Pass --dart-define=VIDEO_FIXTURE=<absolute local MP4 path>',
    );
    MediaKit.ensureInitialized();
    await windowManager.ensureInitialized();
    final player = Player();
    final playback = Playback(NativePlayback(player));
    final starts = <double>[];
    final subscription = player.stream.playing.listen((playing) {
      if (playing) starts.add(player.state.volume);
    });
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
      await playback.open(fixture);
      if (player.state.duration == Duration.zero) {
        await player.stream.duration
            .firstWhere((value) => value > Duration.zero)
            .timeout(const Duration(seconds: 20));
      }
      await tester.pump(const Duration(seconds: 1));
      expect(player.state.volume, 0);
      expect(starts, isNotEmpty);
      expect(starts.every((volume) => volume == 0), isTrue);
      // Keep the fixture silent: only test nonzero volume while paused.
      await player.pause();
      await playback.setVolume(35);
      await player.seek(const Duration(seconds: 2));
      expect(player.state.volume, 35);
      await playback.open(fixture);
      expect(player.state.volume, 0);
      await playback.panic();
      await waitNativeMinimized(tester);
      expect(await windowManager.isMinimized(), isTrue);
      final playing = player.state.playing;
      await restoreNativeWindow(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(player.state.volume, 0);
      expect(player.state.playing, playing);
      expect(tester.takeException(), isNull);
    } finally {
      await restoreNativeWindow(tester);
      await subscription.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      await player.dispose();
    }
  });
}
