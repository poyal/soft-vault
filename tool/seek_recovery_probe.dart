// Release entry point. Arguments: numbered fixture, output JSON, rounds,
// comma-separated gestures, optional native test module and output mode.
// Opens only the supplied file and a temporary DB.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/advanced_catalog.dart';
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/playback_diagnostics.dart';
import 'package:soft_vault/seek_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'seek_dispatch_trial.dart';

Element? findElement(Element root, bool Function(Widget) matches) {
  if (matches(root.widget)) return root;
  Element? result;
  root.visitChildren((child) => result ??= findElement(child, matches));
  return result;
}

Future<void> until(bool Function() condition) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsed.inSeconds > 15)
      throw StateError('Player did not become ready');
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
}

// Read only the centre strip from the test app's own composited layer.
// Readback is timed and separately reported. No desktop capture permission
// or camera is involved; this cannot measure physical panel presentation.
Future<int?> readFrame(OffsetLayer layer, Rect strip) async {
  final image = await layer.toImage(strip, pixelRatio: 64 / strip.width);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return null;
    bool white(int i) => bytes.getUint8((i * 4 + 2) * 4) > 160;
    if (!white(0) || white(14) || !white(15)) return null;
    var id = 0;
    for (var i = 1; i <= 13; i++) {
      if (white(i)) id |= 1 << (i - 1);
    }
    return id;
  } finally {
    image.dispose();
  }
}

KeyEvent key(bool right, String type, Duration time) {
  final physical = right
      ? PhysicalKeyboardKey.arrowRight
      : PhysicalKeyboardKey.arrowLeft;
  final logical = right
      ? LogicalKeyboardKey.arrowRight
      : LogicalKeyboardKey.arrowLeft;
  final event = switch (type) {
    'down' => KeyDownEvent(
      physicalKey: physical,
      logicalKey: logical,
      timeStamp: time,
    ),
    'up' => KeyUpEvent(
      physicalKey: physical,
      logicalKey: logical,
      timeStamp: time,
    ),
    _ => KeyRepeatEvent(
      physicalKey: physical,
      logicalKey: logical,
      timeStamp: time,
    ),
  };
  return event;
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  final fixture = File(args[0]).absolute;
  final out = File(args[1]).absolute;
  final rounds = int.parse(args[2]);
  final gestures = args[3].split(',');
  final fps = switch (p.basenameWithoutExtension(fixture.path)) {
    'long-gop' => 24,
    'vfr' => 30,
    _ => 60,
  };
  final root = await Directory.systemTemp.createTemp('vault-seek-recovery-');
  final library = await Library.open(p.join(root.path, 'catalog.sqlite'));
  final homeKey = GlobalKey();
  final surfaceKey = GlobalKey();
  final records = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'fixture': p.basename(fixture.path),
    'fps': fps,
    'platform': Platform.operatingSystem,
    'measurement':
        'application composited video strip, milliseconds since gesture start',
    'records': records,
  };
  final outputMode = args.length > 5 ? args[5] : '';
  final nativeWindow =
      outputMode == 'native-window' || outputMode == 'native-hw';
  SeekDispatchTrial? dispatch;
  await out.parent.create(recursive: true);
  Future<void> save() =>
      out.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  try {
    if (!await fixture.exists()) throw StateError('Missing fixture');
    await library.setting('welcome_seen', true);
    final id = await library.db.insert('media', {
      'path': fixture.path,
      'folder': root.path,
      'title': 'Playback probe',
      'type': 'video',
      'added': 1,
      'duration': 72,
    });
    runApp(
      MaterialApp(
        home: RepaintBoundary(
          key: surfaceKey,
          child: VaultHome(key: homeKey, library: library),
        ),
      ),
    );
    await windowManager.setSize(const Size(1280, 800));
    await windowManager.show();
    await windowManager.focus();
    await until(() => homeKey.currentState != null);
    final dynamic home = homeKey.currentState;
    home.enrichmentPaused = true;
    final tree = homeKey.currentContext! as Element;
    await until(() => findElement(tree, (w) => w is VaultFileList) != null);
    final list =
        findElement(tree, (w) => w is VaultFileList)!.widget as VaultFileList;
    list.play(await library.mediaById(id));
    final Player player = home.player;
    dispatch = args.length > 4
        ? SeekDispatchTrial(await player.handle, args[4])
        : null;
    void sendKey(bool right, String type, Duration time) {
      if (home.onKey(key(right, type, time)) != KeyEventResult.handled) {
        throw StateError('Playback did not handle $type arrow input');
      }
    }

    final SeekController seeks = home.seeks;
    await until(
      () => home.playbackMediaId == id && player.state.position > Duration.zero,
    );
    final videoBox =
        findElement(
              tree,
              (w) => w.key == const ValueKey('video-surface'),
            )!.renderObject!
            as RenderBox;
    final boundary =
        surfaceKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final actual = applyBoxFit(
      BoxFit.contain,
      const Size(16, 9),
      videoBox.size,
    ).destination;
    final centre = videoBox.localToGlobal(
      videoBox.size.center(Offset.zero),
      ancestor: boundary,
    );
    final strip = Rect.fromCenter(
      center: centre,
      width: actual.width,
      height: 2,
    );
    // Crop the probe's own layer without copying the entire video surface.
    // ignore: invalid_use_of_protected_member
    final layer = boundary.layer! as OffsetLayer;
    final native = player.platform as NativePlayer;
    final video = home.video as VideoController;
    if (outputMode == 'texture-hw' || outputMode == 'texture-software') {
      await native.command([
        'set',
        'hwdec',
        outputMode == 'texture-software' ? 'no' : 'd3d11va',
      ]);
      await player.open(Media(fixture.path));
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    if (outputMode == 'viewport') {
      final ratio = View.of(tree).devicePixelRatio;
      final sourceWidth = player.state.width!,
          sourceHeight = player.state.height!;
      final output = applyBoxFit(
        BoxFit.scaleDown,
        Size(sourceWidth.toDouble(), sourceHeight.toDouble()),
        actual * ratio,
      ).destination;
      await video.setSize(
        width: output.width.ceil(),
        height: output.height.ceil(),
      );
      await until(() => video.rect.value?.width == output.width.ceil());
    }
    if (nativeWindow) {
      final addr = dispatch!.openWindow(
        actual.width.round(),
        actual.height.round(),
      );
      if (addr == 0) throw StateError('Native test window creation failed');
      await player.pause();
      await native.command(['set', 'wid', addr.toString()]);
      await native.command([
        'set',
        'hwdec',
        Platform.isWindows
            ? (outputMode == 'native-hw' ? 'd3d11va' : 'd3d11va-copy')
            : 'videotoolbox',
      ]);
      await native.command(['set', 'vo', 'gpu']);
      await player.open(Media(fixture.path));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      report['measurement'] =
          'test native window barcode, milliseconds since gesture start';
    }
    report['vo'] = await native.getProperty('current-vo');
    report['windowSize'] = [actual.width, actual.height];
    report['textureSize'] = [video.rect.value?.width, video.rect.value?.height];
    Future<int?> frame() async {
      if (!nativeWindow) return readFrame(layer, strip);
      final n = dispatch!.windowFrame();
      return n < 0 ? null : n;
    }

    final diagnostics = PlaybackDiagnostics(player);
    report['initial'] = await diagnostics.sample();
    final check = <int>{};
    for (var i = 0; i < 12; i++) {
      final n = await frame();
      if (n != null) check.add(n);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (check.length < 2)
      throw StateError('Composited frame IDs unavailable: $check');
    for (var round = 0; round < rounds; round++) {
      for (final gesture in round.isEven ? gestures : gestures.reversed) {
        await player.pause();
        final revisit = gesture == 'revisit';
        final startPosition = revisit
            ? const Duration(seconds: 20)
            : Duration(milliseconds: 5500 + round % 9 * 97);
        await seeks.seekTo(startPosition);
        await player.play();
        if (revisit) {
          await until(
            () =>
                player.state.position >
                startPosition + const Duration(milliseconds: 900),
          );
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
        final clock = Stopwatch()..start();
        int? released;
        final captured = <List<num>>[];
        Future<void> observe() async {
          while (released == null ||
              clock.elapsedMilliseconds - released < 2000) {
            final start = clock.elapsedMicroseconds;
            final n = await frame();
            final end = clock.elapsedMicroseconds;
            captured.add([start / 1000, end / 1000, n ?? -1]);
            final delay = 16000 - (end - start);
            if (delay > 0)
              await Future<void>.delayed(Duration(microseconds: delay));
          }
        }

        final before = await diagnostics.sample();
        final originMs = player.state.position.inMilliseconds;
        final controlled = gesture == 'dart' || gesture == 'cpp';
        final submissionUs = <int>[];
        void submit(int index) {
          final at = clock.elapsedMicroseconds;
          dispatch!.dispatch(gesture == 'cpp', index, originMs);
          submissionUs.add(clock.elapsedMicroseconds - at);
        }

        final observing = observe();
        final slider =
            findElement(
                  tree,
                  (w) => w.key == const ValueKey('playback-seek-slider'),
                )!.widget
                as Slider;
        for (var i = 0; i < 10; i++) {
          if (revisit) {
            slider.onChangeStart!(20000);
            slider.onChanged!(20000);
            slider.onChangeEnd!(20000);
            break;
          }
          final right = gesture != 'alternate' || i.isEven;
          switch (gesture) {
            case 'dart':
            case 'cpp':
              submit(i);
            case 'taps':
            case 'alternate':
              sendKey(right, 'down', clock.elapsed);
              sendKey(right, 'up', clock.elapsed);
            case 'hold':
              sendKey(true, i == 0 ? 'down' : 'repeat', clock.elapsed);
              if (i == 9) sendKey(true, 'up', clock.elapsed);
            case 'clicks':
            case 'drag':
              final t = (11000 + i * 4500 + round % 5 * 317).toDouble();
              if (i == 0 || gesture == 'clicks') slider.onChangeStart!(t);
              slider.onChanged!(t);
              if (i == 9 || gesture == 'clicks') slider.onChangeEnd!(t);
            default:
              throw ArgumentError('Unknown gesture $gesture');
          }
          if (i < 9)
            await Future<void>.delayed(const Duration(milliseconds: 80));
        }
        released = clock.elapsedMilliseconds;
        final target = revisit
            ? 20.0
            : controlled
            ? originMs / 1000 + 50
            : seeks.displayPosition.inMicroseconds / 1000000;
        if (controlled) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          submit(10);
        }
        if ((gesture == 'taps' || gesture == 'hold') && target < 54) {
          throw StateError(
            'Ten forward inputs did not reach their destination: $target',
          );
        }
        await observing;
        final after = await diagnostics.sample();
        final valid = captured
            .where((r) => r[2] >= 0 && r[1] >= released!)
            .toList();
        final hits = valid.where((r) {
          final t = r[2] / fps;
          return t >= target - (fps == 30 ? 2 : 1) / fps - .004 &&
              t <= target + (r[1] - released!) / 1000 + .05;
        });
        num previous = released, longest = 0, gap = 0;
        num? lastId;
        for (final r in valid) {
          if (lastId != r[2]) {
            longest = math.max(longest, r[1] - previous);
            previous = r[1];
            lastId = r[2];
          }
        }
        if (valid.isNotEmpty)
          longest = math.max(longest, valid.last[1] - previous);
        for (var i = 1; i < captured.length; i++) {
          gap = math.max(gap, captured[i][1] - captured[i - 1][1]);
        }
        records.add({
          'round': round,
          'gesture': gesture,
          'releaseMs': released,
          'targetSeconds': target,
          'firstTargetMs': hits.isEmpty ? null : hits.first[1] - released,
          'longestUnchangedMs': valid.isEmpty ? null : longest,
          'largestSampleGapMs': gap,
          'samples': captured,
          if (controlled) 'submissionUs': submissionUs,
          'dropBefore': before['frame-drop-count'],
          'dropAfter': after['frame-drop-count'],
          'avsyncAfter': after['avsync'],
          'playing': player.state.playing,
        });
        await save();
      }
    }
    report['complete'] = true;
  } catch (e, stack) {
    report['error'] = '$e\n$stack';
  } finally {
    await save();
    final dynamic home = homeKey.currentState;
    if (home != null) {
      home.closing = true;
      await home.disposePlayer();
    }
    if (nativeWindow) dispatch?.closeWindow();
    await library.close();
    await root.delete(recursive: true);
    exit(report['complete'] == true ? 0 : 1);
  }
}
