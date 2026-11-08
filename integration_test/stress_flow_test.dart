import 'support/native_surface.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show Media;
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/hover_preview.dart';
import 'package:soft_vault/player_controls.dart';
import 'package:window_manager/window_manager.dart';
import 'support/scenario_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (kProfileMode) {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  }
  final results = <Map<String, Object?>>[];
  void scenario(
    String name,
    Future<void> Function(ScenarioApp, Map<String, Object?>) action, {
    int videos = 0,
  }) {
    testWidgets(name, (tester) async {
      ScenarioApp? app;
      final clock = Stopwatch()..start();
      final result = <String, Object?>{
        'name': name,
        'mode': kProfileMode
            ? 'Windows profile integration'
            : 'Windows debug integration',
        'passed': false,
      };
      try {
        app = await ScenarioApp.create(
          tester,
          fixtures: videos == 0 ? 1 : 0,
          videos: videos,
        );
        await action(app, result);
        result['passed'] = true;
      } catch (e) {
        result['error'] = '$e';
        rethrow;
      } finally {
        await app?.close();
        result['ms'] = clock.elapsedMilliseconds;
        results.add(result);
        await Directory('build/e2e').create(recursive: true);
        await File(
          kProfileMode
              ? 'build/e2e/stress-profile-results.json'
              : 'build/e2e/stress-results.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      }
    }, timeout: const Timeout(Duration(minutes: 8)));
  }

  scenario(
    'NATIVE-STRESS-01 rapid file switching ends on the requested video at zero volume',
    (app, result) async {
      await app.mount();
      final tester = app.tester;
      for (var wave = 0; wave < 10; wave++) {
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byType(HoverPreview).at(i % 2));
          await tester.pump(const Duration(milliseconds: 20));
        }
        final expected = app.visible[1];
        await app.until(
          () =>
              find.byType(PlaybackControls).evaluate().isNotEmpty &&
              app.player.state.playlist.medias.isNotEmpty &&
              app.player.state.playlist.medias.last.uri ==
                  Media(expected['path'] as String).uri,
        );
        await app.settle(3);
        expect(app.player.state.volume, 0);
        expect(
          tester.widget<VaultFileList>(find.byType(VaultFileList)).current,
          expected['id'],
        );
      }
      expect(find.byType(MaterialBanner), findsNothing);
      result['opens'] = 40;
    },
    videos: 2,
  );
  scenario(
    'NATIVE-STRESS-02 repeated fullscreen, panic and restore retains safe playback state',
    (app, result) async {
      await app.mount();
      await app.key(LogicalKeyboardKey.space);
      final player = app.player;
      await app.until(() => player.state.playing);
      final rss = ProcessInfo.currentRss;
      for (var i = 0; i < 12; i++) {
        if (i > 0) await app.key(LogicalKeyboardKey.space);
        final wasPlaying = player.state.playing;
        await app.key(LogicalKeyboardKey.keyF);
        expect(await windowManager.isFullScreen(), isTrue);
        await app.key(LogicalKeyboardKey.escape);
        expect(await windowManager.isMinimized(), isTrue);
        await windowManager.restore();
        await app.settle(2);
        expect(player.state.volume, 0);
        expect(player.state.playing, wasPlaying);
        await app.key(LogicalKeyboardKey.keyF);
        expect(await windowManager.isFullScreen(), isFalse);
      }
      result['cycles'] = 12;
      result['rssGrowthBytes'] = ProcessInfo.currentRss - rss;
      expect(ProcessInfo.currentRss - rss, lessThan(256 * 1024 * 1024));
    },
    videos: 1,
  );
  scenario(
    'NATIVE-LOAD-01 10000 rows remain virtualized through scrolling, search and resizing',
    (app, result) async {
      final tester = app.tester, base = (await app.library.items()).single;
      await app.library.db.transaction((tx) async {
        final batch = tx.batch();
        for (var i = 1; i < 10000; i++) {
          final row = Map<String, Object?>.from(base)..remove('id');
          row.addAll({
            'path': '${app.root.path}/virtual-$i.mp4',
            'folder': '${app.root.path}/virtual',
            'title': 'record-${i.toString().padLeft(5, '0')}',
            'online': 0,
          });
          batch.insert('media', row);
        }
        await batch.commit(noResult: true);
      });
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> values) => frames.addAll(values);
      tester.binding.addTimingsCallback(collect);
      try {
        final startup = Stopwatch()..start();
        await app.mount();
        await app.until(() => app.visible.length == 10000);
        result['startupMs'] = startup.elapsedMilliseconds;
        expect(startup.elapsed, lessThan(const Duration(seconds: 15)));
        final rss = ProcessInfo.currentRss;
        var maxTiles = 0;
        for (var round = 0; round < 4; round++) {
          final width = [1000.0, 1280.0, 1440.0, 1920.0][round];
          final size = Size(width, 900);
          await resizeNativeSurface(tester, size);
          await app.settle(2);
          await app.menu('썸네일 · 목록 보기');
          final scroll = find
              .descendant(
                of: find.byType(VaultFileList),
                matching: find.byType(Scrollable),
              )
              .first;
          for (var i = 0; i < 20; i++) {
            await tester.drag(scroll, Offset(0, i < 10 ? -400 : 400));
            await tester.pump(const Duration(milliseconds: 16));
            final tiles = find.byType(HoverPreview).evaluate().length;
            if (tiles > maxTiles) maxTiles = tiles;
            expect(tiles, lessThan(80));
            expect(tester.takeException(), isNull);
          }
        }
        final times = <int>[];
        for (var i = 0; i < 10; i++) {
          await tester.tap(find.byTooltip('검색 · Ctrl/Cmd+K'));
          await app.settle(2);
          final watch = Stopwatch()..start();
          final query = 'record-${(i * 997 + 1).toString().padLeft(5, '0')}';
          await app.enterText(find.byType(TextField).last, query);
          await app.until(
            () => find
                .descendant(
                  of: find.byType(ListTile),
                  matching: find.text(query),
                )
                .evaluate()
                .isNotEmpty,
          );
          times.add(watch.elapsedMilliseconds);
          await tester.tap(find.byTooltip('검색 닫기'));
          await app.settle(2);
        }
        times.sort();
        result['searchP95Ms'] = times.last;
        result['maxBuiltTiles'] = maxTiles;
        result['scrollGestures'] = 80;
        result['rssGrowthBytes'] = ProcessInfo.currentRss - rss;
        result['records'] = 10000;
        await app.settle(5);
        if (frames.isNotEmpty) {
          double percentile(Iterable<int> values) {
            final sorted = values.map((value) => value / 1000).toList()..sort();
            return sorted[(sorted.length * .95).floor().clamp(
              0,
              sorted.length - 1,
            )];
          }

          final refreshHz =
              PlatformDispatcher.instance.displays.first.refreshRate;
          final budgetUs = 1000000 / (refreshHz > 0 ? refreshHz : 60);
          result['frameBuildP95Ms'] = percentile(
            frames.map((frame) => frame.buildDuration.inMicroseconds),
          );
          result['frameRasterP95Ms'] = percentile(
            frames.map((frame) => frame.rasterDuration.inMicroseconds),
          );
          result['displayRefreshHz'] = refreshHz;
          result['overBudgetFrames'] = frames
              .where(
                (frame) =>
                    frame.buildDuration.inMicroseconds > budgetUs ||
                    frame.rasterDuration.inMicroseconds > budgetUs,
              )
              .length;
          final durations =
              frames.map((f) => f.totalSpan.inMicroseconds / 1000).toList()
                ..sort();
          result['frameSamples'] = durations.length;
          result[kProfileMode ? 'profileFrameP95Ms' : 'debugFrameP95Ms'] =
              durations[(durations.length * .95).floor().clamp(
                0,
                durations.length - 1,
              )];
        }
        expect(times.last, lessThan(2000));
        expect(ProcessInfo.currentRss - rss, lessThan(384 * 1024 * 1024));
        expect(find.byType(MaterialBanner), findsNothing);
      } finally {
        tester.binding.removeTimingsCallback(collect);
      }
    },
  );
}
