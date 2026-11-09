import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';
import 'support/scenario_app.dart';
import 'support/settings_navigation.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('continuous native resizing', (tester) async {
    final app = await ScenarioApp.create(tester, fixtures: 4);
    final frames = <FrameTiming>[];
    final records = <Map<String, Object?>>[];
    void collect(List<FrameTiming> batch) => frames.addAll(batch);
    double percentile(Iterable<int> data, double q) {
      final values = data.toList()..sort();
      return values.isEmpty
          ? 0
          : values[((values.length - 1) * q).round()] / 1000;
    }

    try {
      await app.mount();
      binding.addTimingsCallback(collect);
      for (final section in [
        'list',
        '라이브러리',
        '재생',
        '단축키',
        '사생활 보호',
        '백업',
        '앱 정보 · 업데이트',
      ]) {
        if (section != 'list') await openSettings(tester, section);
        for (var run = 0; run < 3; run++) {
          frames.clear();
          final rss = ProcessInfo.currentRss;
          for (var i = 0; i < 60; i++) {
            final step = i < 30 ? i : 59 - i;
            await windowManager.setSize(Size(1000 + step * 30, 740 + step * 8));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await app.settle(12);
          expect(frames, isNotEmpty);
          records.add({
            'section': section,
            'run': run,
            'frames': frames.length,
            'buildP50Ms': percentile(
              frames.map((f) => f.buildDuration.inMicroseconds),
              .5,
            ),
            'buildP95Ms': percentile(
              frames.map((f) => f.buildDuration.inMicroseconds),
              .95,
            ),
            'rasterP95Ms': percentile(
              frames.map((f) => f.rasterDuration.inMicroseconds),
              .95,
            ),
            'maxMs': percentile(
              frames.map((f) => f.totalSpan.inMicroseconds),
              1,
            ),
            'overBudget': frames
                .where(
                  (f) =>
                      f.buildDuration.inMicroseconds > 16667 ||
                      f.rasterDuration.inMicroseconds > 16667,
                )
                .length,
            'rssDelta': ProcessInfo.currentRss - rss,
          });
        }
        if (section != 'list') await app.tap('영상으로 돌아가기');
      }
      await Directory('build/verification').create(recursive: true);
      await File(
        'build/verification/resize-${const String.fromEnvironment('RUN_LABEL', defaultValue: 'after')}.json',
      ).writeAsString(
        jsonEncode({'profile': kProfileMode, 'records': records}),
      );
    } finally {
      binding.removeTimingsCallback(collect);
      await app.close();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
