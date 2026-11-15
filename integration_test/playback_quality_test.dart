import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/playback_diagnostics.dart';
import 'package:soft_vault/player_controls.dart';
import 'package:window_manager/window_manager.dart';
import 'support/native_surface.dart';

/// Identical harness can run against the archived baseline. Uses native frame
/// readiness, not command acknowledgements or Flutter's UI FPS, as seek evidence.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('playback quality: native frames, timeline and repeated input', (
    tester,
  ) async {
    const fixtures = String.fromEnvironment('PLAYBACK_FIXTURES');
    const label = String.fromEnvironment(
      'PLAYBACK_LABEL',
      defaultValue: 'candidate',
    );
    const filter = String.fromEnvironment('PLAYBACK_FILTER');
    const seconds = int.fromEnvironment('PLAYBACK_SECONDS', defaultValue: 300);
    const seeks = int.fromEnvironment('PLAYBACK_SEEKS', defaultValue: 30);
    const drags = int.fromEnvironment('PLAYBACK_DRAGS', defaultValue: 1);
    const candidate = bool.fromEnvironment('PLAYBACK_CANDIDATE');
    const loop = bool.fromEnvironment('PLAYBACK_LOOP');
    expect(Directory(fixtures).existsSync(), isTrue);
    MediaKit.ensureInitialized();
    await windowManager.ensureInitialized();
    await prepareNativeSurface(tester);
    await resizeNativeSurface(tester, const Size(1280, 800));
    await windowManager.setTitle('Soft Vault · playback quality · $label');
    final temp = await Directory.systemTemp.createTemp(
      'vault-playback-quality-',
    );
    final library = await Library.open(p.join(temp.path, 'db.sqlite'));
    await library.setting('welcome_seen', true);
    await library.connect(fixtures, verifyContents: false);
    final rows =
        (await library.items())
            .where(
              (r) => filter.isEmpty || (r['path'] as String).contains(filter),
            )
            .toList()
          ..sort(
            (a, b) => (a['path'] as String).compareTo(b['path'] as String),
          );
    expect(rows, isNotEmpty);
    final records = <Map<String, Object?>>[];
    final errors = <String>[];
    final frameTimes = <ui.FrameTiming>[];
    void timings(List<ui.FrameTiming> batch) => frameTimes.addAll(batch);
    final output = File('build/playback-quality/$label.json');
    await output.parent.create(recursive: true);
    Future<void> save() => output.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'label': label,
        'os': Platform.operatingSystemVersion,
        'mode': kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug'),
        'measurement':
            'input callback to native seeking=no (restart_complete) and target playback-time; not physical display latency',
        'physicalSize': [
          ui.PlatformDispatcher.instance.views.first.physicalSize.width,
          ui.PlatformDispatcher.instance.views.first.physicalSize.height,
        ],
        'dpr': ui.PlatformDispatcher.instance.views.first.devicePixelRatio,
        'refreshHz': ui.PlatformDispatcher.instance.displays.first.refreshRate,
        'loopEnabled': loop,
        'requestedSecondsPerFile': seconds,
        'records': records,
        'errors': errors,
      }),
    );
    await tester.pumpWidget(VaultApp(library: library));
    final dynamic home = tester.state(find.byType(VaultHome));
    home.enrichmentPaused = true;
    final Player player = home.player;
    final native = player.platform as NativePlayer;
    final diagnostics = PlaybackDiagnostics(player);
    var variableFrameRate = false;
    final subscription = player.stream.error.listen(errors.add);
    Future<void> pump([int ms = 16]) => tester.pump(Duration(milliseconds: ms));
    Future<void> waitFor(bool Function() ready) async {
      final timer = Stopwatch()..start();
      while (!ready() && timer.elapsed < const Duration(seconds: 15)) {
        await pump(20);
      }
      expect(ready(), isTrue);
    }

    Future<double> frameReady(double target, Stopwatch elapsed) async {
      final fps =
          double.tryParse(await native.getProperty('container-fps')) ?? 24;
      // This fixture alternates 15 and 30 fps; container-fps alone reports 30.
      final tolerance =
          1 / (variableFrameRate ? 15 : (fps > 0 ? fps : 24)) + .004;
      while (elapsed.elapsed < const Duration(seconds: 15)) {
        final pending = await native.getProperty('seeking');
        final pts = double.tryParse(await native.getProperty('playback-time'));
        if (pending == 'no' &&
            pts != null &&
            pts >= target - tolerance &&
            pts <= target + tolerance) {
          return elapsed.elapsedMicroseconds / 1000;
        }
        await pump(8);
      }
      fail('No target frame at $target: ${await diagnostics.sample()}');
    }

    Slider timeline() => tester.widget<Slider>(
      find
          .descendant(
            of: find.byType(PlaybackControls),
            matching: find.byType(Slider),
          )
          .first,
    );
    try {
      await waitFor(() => find.byType(VaultFileList).evaluate().isNotEmpty);
      tester.binding.addTimingsCallback(timings);
      for (final row in rows) {
        variableFrameRate = (row['path'] as String).contains('-vfr.');
        final record = <String, Object?>{
          'file': p.basename(row['path'] as String),
        };
        records.add(record);
        final opened = Stopwatch()..start();
        tester.widget<VaultFileList>(find.byType(VaultFileList)).play(row);
        await waitFor(
          () =>
              home.playbackMediaId == row['id'] &&
              player.state.position > Duration.zero,
        );
        record['openProgressMs'] = opened.elapsedMicroseconds / 1000;
        await player.setVolume(0);
        await player.pause();
        await pump(100);
        record['initial'] = await diagnostics.sample();
        final samples = <Map<String, Object?>>[];
        record['seeks'] = samples;
        final length = player.state.duration.inMilliseconds / 1000;
        for (var i = 0; i < seeks; i++) {
          final target = (length * (.1 + ((i * 37) % 79) / 100)).clamp(
            1.0,
            length - 1,
          );
          final timer = Stopwatch()..start();
          final slider = timeline();
          slider.onChangeStart?.call(target * 1000);
          slider.onChanged!(target * 1000);
          slider.onChangeEnd?.call(target * 1000);
          await pump();
          final uiMs = (timeline().value - target * 1000).abs() < 2
              ? timer.elapsedMicroseconds / 1000
              : null;
          final ready = await frameReady(target, timer);
          samples.add({
            'targetSeconds': target,
            'uiFeedbackMs': uiMs,
            'nativeFrameReadyMs': ready,
            'playbackTime': await native.getProperty('playback-time'),
          });
          if (candidate) await home.seeks.finish();
          await pump(30);
        }
        await save();

        final dragSamples = <Map<String, Object?>>[];
        record['drags'] = dragSamples;
        for (var attempt = 0; attempt < drags; attempt++) {
          final drag = timeline();
          drag.onChangeStart?.call(length * .2 * 1000);
          final dragging = Stopwatch()..start();
          for (var i = 0; i < 120; i++) {
            timeline().onChanged!(length * (.2 + .6 * i / 119) * 1000);
            await pump(8);
          }
          final released = Stopwatch()..start();
          timeline().onChangeEnd?.call(length * .8 * 1000);
          record['dragReleaseFrameMs'] = await frameReady(
            length * .8,
            released,
          );
          record['dragElapsedMs'] = dragging.elapsedMilliseconds;
          dragSamples.add({
            'nativeFrameReadyMs': record['dragReleaseFrameMs'],
            'elapsedMs': record['dragElapsedMs'],
          });
          if (candidate) await home.seeks.finish();
          // Consume the same completion boundary before the next fixture step.
          await pump(80);
          if (drags > 1) await save();
        }

        if (candidate) {
          await home.seeks.seekTo(const Duration(seconds: 10));
        } else {
          await player.seek(const Duration(seconds: 10));
        }
        await frameReady(10, Stopwatch()..start());
        await pump(100);
        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        for (var i = 0; i < 9; i++) {
          await tester.sendKeyRepeatEvent(
            LogicalKeyboardKey.arrowRight,
            physicalKey: PhysicalKeyboardKey.arrowRight,
          );
          await pump(20);
        }
        await tester.sendKeyUpEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await pump(1000);
        record['tenKeyStepsFrom10Seconds'] =
            player.state.position.inMilliseconds / 1000;
        record['applicationError'] = home.error;
        if (candidate) {
          expect(player.state.position.inMilliseconds / 1000, closeTo(60, .1));
          expect(home.seeks.busy, isFalse);
          expect(home.error, isNull);
        }

        if (candidate) {
          await home.seeks.seekTo(const Duration(seconds: 2));
        } else {
          await player.seek(const Duration(seconds: 2));
        }
        await frameReady(2, Stopwatch()..start());
        if (loop) await player.setPlaylistMode(PlaylistMode.single);
        await player.play();
        await pump(1000);
        frameTimes.clear();
        final playback = <Map<String, Object?>>[];
        record['playbackSamples'] = playback;
        final running = Stopwatch()..start();
        var loopIndex = 0, lastSavedMinute = 0, stalledSamples = 0;
        double? previousPosition;
        while (running.elapsed.inSeconds < seconds) {
          final sample = await diagnostics.sample();
          final position = sample['playback-time'];
          if (position is num) {
            if (loop && previousPosition != null) {
              stalledSamples = (position - previousPosition).abs() < .01
                  ? stalledSamples + 1
                  : 0;
              expect(
                stalledSamples,
                lessThan(5),
                reason: 'Soak playback stopped advancing',
              );
            }
            if (previousPosition != null && position < previousPosition - 2) {
              loopIndex++;
            }
            previousPosition = position.toDouble();
          }
          sample['loopIndex'] = loopIndex;
          sample['elapsedMs'] = running.elapsedMilliseconds;
          sample['rss'] = ProcessInfo.currentRss;
          playback.add(sample);
          if (loop && running.elapsed.inMinutes > lastSavedMinute) {
            lastSavedMinute = running.elapsed.inMinutes;
            await save();
          }
          await pump(1000);
        }
        if (loop) {
          expect(player.state.playing, isTrue);
          expect(loopIndex, greaterThanOrEqualTo((seconds / length).floor()));
        }
        await player.pause();
        if (loop) {
          await player.setPlaylistMode(PlaylistMode.none);
          record['completedLoops'] = loopIndex;
          // Confirm the coordinator remains responsive after the sustained run.
          final response = Stopwatch()..start();
          final slider = timeline();
          slider.onChangeStart?.call(10000);
          slider.onChanged!(10000);
          slider.onChangeEnd?.call(10000);
          record['postSoakSeekMs'] = await frameReady(10, response);
          await pump(100);
          if (candidate) {
            expect(home.seeks.busy, isFalse);
            expect(home.error, isNull);
          }
        }
        record['flutterFrames'] = frameTimes
            .map(
              (f) => [
                f.buildDuration.inMicroseconds,
                f.rasterDuration.inMicroseconds,
              ],
            )
            .toList();
        final png = await player.screenshot(format: 'image/png');
        expect(png, isNotNull);
        await File(
          'build/playback-quality/$label-${record['file']}.png',
        ).writeAsBytes(png!);
        expectNativeSurface(tester);
        expect(tester.takeException(), isNull);
        await save();
      }
      expect(errors, isEmpty);
    } finally {
      tester.binding.removeTimingsCallback(timings);
      await subscription.cancel();
      await save();
      home.closing = true;
      await player.pause();
      await home.disposePlayer();
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(400);
      await library.close();
      await temp.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(hours: 2)));
}
