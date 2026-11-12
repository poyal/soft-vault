import 'support/file_navigation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soft_vault/main.dart';
import 'support/scenario_app.dart';
import 'support/settings_navigation.dart';

// Diagnostic A/B only: production widgets and their default blur are unchanged.
// Disable the actual render filter after the first route frame, then exercise
// the same opening/closing transitions. The first frame stays in both samples.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('isolate dialog blur and measure UI/database latency', (
    tester,
  ) async {
    expect(kProfileMode, isTrue, reason: 'Run with flutter drive --profile');
    final app = await ScenarioApp.create(tester, fixtures: 4);
    final frames = <FrameTiming>[];
    final results = <Map<String, Object?>>[];
    void collect(List<FrameTiming> batch) => frames.addAll(batch);
    double percentile(Iterable<int> values, double p) {
      final sorted = values.toList()..sort();
      return sorted[((sorted.length - 1) * p).round()] / 1000;
    }

    Future<void> phase(String name, Future<void> Function() action) async {
      await app.settle(12);
      frames.clear();
      final elapsed = Stopwatch()..start();
      await action();
      elapsed.stop();
      await app.settle(12);
      expect(frames, isNotEmpty);
      final hz = PlatformDispatcher.instance.displays.first.refreshRate;
      final budget = 1000000 / (hz > 0 ? hz : 60);
      results.add({
        'phase': name,
        'actionWallMs': elapsed.elapsedMilliseconds,
        'frames': frames.length,
        'buildP95Ms': percentile(
          frames.map((f) => f.buildDuration.inMicroseconds),
          .95,
        ),
        'rasterMedianMs': percentile(
          frames.map((f) => f.rasterDuration.inMicroseconds),
          .5,
        ),
        'rasterP95Ms': percentile(
          frames.map((f) => f.rasterDuration.inMicroseconds),
          .95,
        ),
        'rasterOverBudget': frames
            .where((f) => f.rasterDuration.inMicroseconds > budget)
            .length,
        'refreshHz': hz,
      });
    }

    Future<void> dialogs(String kind, bool blur) async {
      for (var i = 0; i < 8; i++) {
        if (kind == 'search') {
          await tester.tap(find.byTooltip('검색 · Ctrl/Cmd+K'));
        } else {
          await openFileDetails(tester);
        }
        await tester.pump();
        final filters = find.byType(BackdropFilter);
        expect(filters, findsOneWidget);
        tester.renderObject<RenderBackdropFilter>(filters).enabled = blur;
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        await tester.tap(
          kind == 'search' ? find.byTooltip('검색 닫기') : find.text('닫기'),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
      }
    }

    try {
      await app.mount();
      binding.addTimingsCallback(collect);
      final queryUs = <int>[];
      final selectionUs = <int>[];
      for (var i = 0; i < 30; i++) {
        final watch = Stopwatch()..start();
        await app.library.items(query: 'fixture', limit: 3);
        queryUs.add(watch.elapsedMicroseconds);
      }
      final home = tester.state(find.byType(VaultHome)) as dynamic;
      final rows = await app.library.items();
      for (var i = 0; i < 12; i++) {
        final watch = Stopwatch()..start();
        await home.select(rows[i % rows.length]);
        selectionUs.add(watch.elapsedMicroseconds);
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
      }
      for (final round in [1, 2]) {
        // Reverse order on repeat to reduce warm-up/order bias.
        for (final blur in round == 1 ? [true, false] : [false, true]) {
          for (final kind in ['search', 'detail']) {
            await phase(
              '$kind-blur-$blur-round-$round',
              () => dialogs(kind, blur),
            );
          }
        }
      }
      Future<void> navigate() => phase('navigation', () async {
        for (var i = 0; i < 6; i++) {
          await app.tap('배우');
          await app.tap('태그');
          await openSettings(tester);
          await app.tap('영상으로 돌아가기');
        }
      });
      if (const bool.fromEnvironment('TRACE_DIAGNOSTICS')) {
        await binding.traceAction(navigate, reportKey: 'navigationTimeline');
        await File(
          'build/e2e/bottleneck-timeline.json',
        ).writeAsString(jsonEncode(binding.reportData!['navigationTimeline']));
      } else {
        await navigate();
      }
      // Control workload: a changing full-window color with no app widgets,
      // database, thumbnails, text, blur or media texture.
      await tester.pumpWidget(const MaterialApp(home: _PaintControl()));
      await phase('minimal-flutter-animation', () => app.settle(30));
      await File('build/e2e/bottleneck-diagnostics.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'mode': 'profile',
          'framePolicy': binding.framePolicy.name,
          'records': 4,
          'dialogCyclesPerPhase': 8,
          'querySamples': queryUs.length,
          'queryMedianMs': percentile(queryUs, .5),
          'queryP95Ms': percentile(queryUs, .95),
          'selectionHandlerMedianMs': percentile(selectionUs, .5),
          'selectionHandlerP95Ms': percentile(selectionUs, .95),
          'note':
              'Wall time includes real dialog animations and test pump intervals; it is not input-to-photon latency. Blur toggled on render object for this diagnostic only.',
          'phases': results,
        }),
      );
    } finally {
      binding.removeTimingsCallback(collect);
      await app.close();
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}

class _PaintControl extends StatefulWidget {
  const _PaintControl();
  @override
  State<_PaintControl> createState() => _PaintControlState();
}

class _PaintControlState extends State<_PaintControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (_, _) => ColoredBox(
      color: Color.lerp(
        const Color(0xff15191e),
        const Color(0xff242c35),
        animation.value,
      )!,
    ),
  );
}
