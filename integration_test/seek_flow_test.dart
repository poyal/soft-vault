import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/seek_controller.dart';
import 'support/scenario_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'native seeks preserve state, switch files safely and defer automatic disk work',
    (tester) async {
      final app = await ScenarioApp.create(tester);
      try {
        await app.mount();
        final dynamic home = tester.state(find.byType(VaultHome));
        final SeekController seeks = home.seeks;
        final rows = await app.library.items();
        void play(int index) => tester
            .widget<VaultFileList>(find.byType(VaultFileList))
            .play(rows[index]);
        play(0);
        await app.until(() => home.playbackMediaId == rows[0]['id']);
        await app.player.pause();
        await seeks.seekTo(const Duration(seconds: 10));
        expect(seeks.busy, isFalse);
        await app.player.setVolume(37);
        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyRepeatEvent(
            LogicalKeyboardKey.arrowRight,
            physicalKey: PhysicalKeyboardKey.arrowRight,
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.sendKeyUpEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await app.until(() => !seeks.busy);
        expect(app.player.state.position.inMilliseconds, closeTo(30000, 80));
        expect(app.player.state.volume, 37);
        expect(app.player.state.playing, isFalse);
        await app.settle(5);
        expect(app.player.state.position.inMilliseconds, closeTo(30000, 80));

        final slider = find.byKey(const ValueKey('playback-seek-slider'));
        final start = tester.getCenter(slider);
        final gesture = await tester.startGesture(start);
        for (var i = 1; i <= 8; i++) {
          await gesture.moveTo(start + Offset(i * 10, 0));
          await tester.pump(const Duration(milliseconds: 25));
        }
        final intended = seeks.displayPosition;
        await gesture.up();
        await app.until(() => !seeks.busy);
        expect(
          app.player.state.position.inMilliseconds,
          closeTo(intended.inMilliseconds, 80),
        );
        await seeks.undo();
        expect(app.player.state.position.inMilliseconds, closeTo(30000, 80));
        expect(app.player.state.playing, isFalse);

        seeks.seekTo(const Duration(seconds: 45));
        play(1);
        await app.until(
          () => home.playbackMediaId == rows[1]['id'] && !seeks.busy,
        );
        await app.player.pause();
        expect(app.player.state.position.inSeconds, lessThan(4));
        expect(app.player.state.volume, 0);
        await seeks.seekTo(app.player.state.duration);
        await seeks.seekTo(const Duration(seconds: 1));
        expect(app.player.state.completed, isFalse);

        await app.player.setRate(3);
        await app.player.play();
        await seeks.seekTo(const Duration(seconds: 20));
        expect(seeks.busy, isFalse);
        expect(app.player.state.playing, isTrue);
        expect(app.player.state.rate, 3);
        // Delay observing completion, as can happen while a native frame stalls
        // the UI, and pause after playback has already advanced past the target.
        final NativePlayback nativePlayback = home.nativePlayback;
        await nativePlayback.seek(const Duration(seconds: 20), exact: true);
        await app.until(() => app.player.state.position.inMilliseconds > 20500);
        await app.player.pause();
        await app.player.setRate(1);
        expect(
          await nativePlayback.settled(const Duration(seconds: 20)),
          isTrue,
        );

        // A real filesystem watch must wait until playback pauses before scanning.
        await app.player.play();
        final added = p.join(app.source.path, 'deferred.mp4');
        await File(rows.first['path'] as String).copy(added);
        await app.until(() => home.backgroundScanPending as bool);
        expect((await app.library.items()).length, rows.length);
        await app.player.pause();
        for (
          var i = 0;
          i < 100 && (await app.library.items()).length == rows.length;
          i++
        ) {
          await app.settle(1);
        }
        expect((await app.library.items()).length, rows.length + 1);
        expect(home.error, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await app.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
