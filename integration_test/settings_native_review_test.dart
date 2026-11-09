import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/app_updater.dart';
import 'package:soft_vault/hover_preview.dart';
import 'package:soft_vault/player_controls.dart';
import 'package:window_manager/window_manager.dart';
import 'support/scenario_app.dart';
import 'support/settings_navigation.dart';
import 'support/native_surface.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('settings native review and playback resizing', (tester) async {
    final app = await ScenarioApp.create(tester, fixtures: 4);
    final capture = GlobalKey();
    final frames = <ui.FrameTiming>[];
    final results = <Map<String, Object?>>[];
    void collect(List<ui.FrameTiming> batch) => frames.addAll(batch);
    try {
      AppUpdater.instance = AppUpdater(Directory('${app.root.path}/updates'))
        ..current = '0.1.0+1'
        ..message = '최신 버전입니다.';
      await resizeNativeSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: VaultApp(library: app.library),
        ),
      );
      await app.settle(15);
      final home = tester.state(find.byType(VaultHome)) as dynamic;
      final current = home.current;
      for (final section in [
        '라이브러리',
        '재생',
        '단축키',
        '사생활 보호',
        '백업',
        '앱 정보 · 업데이트',
      ]) {
        await openSettings(tester, section);
        expect(find.byKey(const ValueKey('library-sidebar')), findsNothing);
        await app.settle();
        final image =
            await (capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/settings-native-review').create(recursive: true);
        await File(
          'build/settings-native-review/$section.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        await app.tap('영상으로 돌아가기');
        expect(home.current, current);
      }
      await tester.tap(find.byType(HoverPreview).first);
      await app.until(
        () => find.byType(PlaybackControls).evaluate().isNotEmpty,
      );
      await app.settle(15);
      final player = home.player;
      binding.addTimingsCallback(collect);
      for (final playing in [true, false]) {
        if (playing) {
          await player.play();
        } else {
          await player.pause();
        }
        for (var run = 0; run < 3; run++) {
          frames.clear();
          for (var i = 0; i < 60; i++) {
            final step = i < 30 ? i : 59 - i;
            await windowManager.setSize(Size(1000 + step * 30, 740 + step * 8));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await app.settle(12);
          double p95(Iterable<int> values) {
            final sorted = values.toList()..sort();
            return sorted[((sorted.length - 1) * .95).round()] / 1000;
          }

          results.add({
            'playing': playing,
            'run': run,
            'frames': frames.length,
            'buildP95Ms': p95(
              frames.map((f) => f.buildDuration.inMicroseconds),
            ),
            'rasterP95Ms': p95(
              frames.map((f) => f.rasterDuration.inMicroseconds),
            ),
          });
        }
      }
      final position = player.state.position;
      await openSettings(tester);
      await app.tap('영상으로 돌아가기');
      expect(identical(home.player, player), true);
      expect(player.state.playing, false);
      expect(
        (player.state.position - position).inMilliseconds.abs(),
        lessThan(1000),
      );
      await File(
        'build/verification/playback-resize.json',
      ).writeAsString(jsonEncode(results));
    } finally {
      binding.removeTimingsCallback(collect);
      AppUpdater.instance = null;
      await app.close();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
