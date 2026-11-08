import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soft_vault/hover_preview.dart';
import 'package:soft_vault/player_controls.dart';
import 'support/scenario_app.dart';
import 'support/settings_navigation.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (kProfileMode) {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  }
  testWidgets('profile normal four-video navigation, dialogs and playback', (
    tester,
  ) async {
    final app = await ScenarioApp.create(tester, fixtures: 4);
    final frames = <FrameTiming>[];
    final results = <Map<String, Object?>>[];
    void collect(List<FrameTiming> batch) => frames.addAll(batch);
    double p95(Iterable<int> values) {
      final sorted = values.map((value) => value / 1000).toList()..sort();
      return sorted[(sorted.length * .95).floor().clamp(0, sorted.length - 1)];
    }

    Future<void> phase(String name, Future<void> Function() action) async {
      frames.clear();
      await action();
      // Native frame timings are batched. Drain them before changing phases.
      await app.settle(12);
      expect(frames, isNotEmpty);
      final hz = PlatformDispatcher.instance.displays.first.refreshRate;
      final budgetUs = 1000000 / (hz > 0 ? hz : 60);
      results.add({
        'phase': name,
        'frames': frames.length,
        'buildP95Ms': p95(
          frames.map((frame) => frame.buildDuration.inMicroseconds),
        ),
        'rasterP95Ms': p95(
          frames.map((frame) => frame.rasterDuration.inMicroseconds),
        ),
        'totalP95Ms': p95(
          frames.map((frame) => frame.totalSpan.inMicroseconds),
        ),
        'overBudgetFrames': frames
            .where(
              (frame) =>
                  frame.buildDuration.inMicroseconds > budgetUs ||
                  frame.rasterDuration.inMicroseconds > budgetUs,
            )
            .length,
        'refreshHz': hz,
      });
      await File('build/e2e/ui-profile-results.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'mode': kProfileMode ? 'profile' : 'debug',
          'framePolicy': binding.framePolicy.name,
          'records': 4,
          'phases': results,
        }),
      );
    }

    try {
      await app.mount();
      tester.binding.addTimingsCallback(collect);
      await phase('navigation', () async {
        for (var i = 0; i < 4; i++) {
          await app.tap('배우');
          await app.tap('태그');
          await openSettings(tester);
          await app.tap('영상으로 돌아가기');
        }
      });
      await phase('search-dialog', () async {
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.byTooltip('검색 · Ctrl/Cmd+K'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('검색 닫기'));
          await tester.pumpAndSettle();
        }
      });
      await phase('detail-dialog', () async {
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.byTooltip('상세정보 보기'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('닫기'));
          await tester.pumpAndSettle();
        }
      });
      await phase('video-playback', () async {
        await tester.tap(find.byType(HoverPreview).first);
        await app.until(
          () => find.byType(PlaybackControls).evaluate().isNotEmpty,
        );
        await app.settle(30);
      });
    } finally {
      tester.binding.removeTimingsCallback(collect);
      await app.close();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
