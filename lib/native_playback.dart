import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'playback.dart';
import 'seek_controller.dart';

class NativePlayback implements PlaybackPort, SeekPort {
  final Player player;
  NativePlayback(this.player);
  late final Future<void> ready = _configure();
  final _seekClock = Stopwatch();
  bool _seekWasPlaying = false;
  double _seekRate = 1;
  NativePlayer get native => player.platform as NativePlayer;

  Future<void> _configure() async {
    // Applied after media_kit and the video controller have installed defaults.
    const forward = int.fromEnvironment('PLAYBACK_CACHE_MB', defaultValue: 64);
    const backward = int.fromEnvironment(
      'PLAYBACK_BACK_CACHE_MB',
      defaultValue: 32,
    );
    for (final property in {
      'cache': 'yes',
      'cache-on-disk': 'no',
      'demuxer-max-bytes': '${forward * 1024 * 1024}',
      'demuxer-max-back-bytes': '${backward * 1024 * 1024}',
      'hr-seek': 'yes',
      'hr-seek-framedrop': 'yes',
    }.entries) {
      await native.setProperty(property.key, property.value);
    }
  }

  @override
  Duration get position => player.state.position;
  @override
  Duration get duration => player.state.duration;
  @override
  Future<void> seek(Duration position, {required bool exact}) async {
    await ready;
    _seekClock
      ..reset()
      ..start();
    _seekWasPlaying = player.state.playing;
    _seekRate = player.state.rate;
    if (player.state.completed) {
      // Reset media_kit's completed/replay state before moving away from EOF.
      await player.seek(position);
    }
    final seconds = (position.inMicroseconds / Duration.microsecondsPerSecond)
        .toString();
    if (exact) {
      // mpv's seek command delays consecutive requests by up to 300 ms. The
      // time-pos setter queues an absolute seek without that delay; hr-seek=yes
      // still decodes to the exact target. A released drag must commit promptly.
      await native.setProperty('time-pos', seconds);
    } else {
      await native.command(['seek', seconds, 'absolute+keyframes']);
    }
  }

  @override
  Future<bool> settled(Duration position) async {
    // A user can pause or reduce speed before the completion poll runs. Keep
    // the progress already allowed by playback instead of requiring a rewind.
    _seekWasPlaying = _seekWasPlaying || player.state.playing;
    if (player.state.rate > _seekRate) _seekRate = player.state.rate;
    if (await native.getProperty('seeking') == 'yes') return false;
    // Bundled mpv 0.36 has no video-pts. seeking=no means restart_complete:
    // use its native playback timestamp after that decoder completion boundary.
    final pts = double.tryParse(await native.getProperty('playback-time'));
    // media_kit's buffering flag also follows core-idle and can remain true
    // after a paused seek. Only actual cache starvation blocks completion.
    if (pts == null || await native.getProperty('paused-for-cache') == 'yes') {
      return false;
    }
    final fps =
        double.tryParse(await native.getProperty('container-fps')) ?? 24;
    final frame = (1 / (fps > 0 ? fps : 24)).clamp(.1, double.infinity);
    final target = position.inMicroseconds / Duration.microsecondsPerSecond;
    if (target >=
            duration.inMicroseconds / Duration.microsecondsPerSecond - frame &&
        player.state.completed)
      return true;
    final advanced = _seekWasPlaying
        ? _seekClock.elapsedMicroseconds /
              Duration.microsecondsPerSecond *
              _seekRate
        : 0.0;
    return pts >= target - frame - .002 &&
        pts <= target + advanced + frame + .002;
  }

  @override
  Future<void> volume(double value) => player.setVolume(value);
  @override
  Future<void> openPaused(String path, {Duration start = Duration.zero}) async {
    await ready;
    await player.open(Media(path, start: start), play: false);
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> minimize() async {
    if (Platform.isWindows) {
      await const MethodChannel(
        'soft_vault/window',
      ).invokeMethod<void>('minimize');
    } else {
      if (Platform.isMacOS && await windowManager.isFullScreen()) {
        // AppKit cannot miniaturize a window while it belongs to a fullscreen
        // Space. Wait for the native transition, rather than only its request.
        await setNativeFullscreen(false);
      }
      await windowManager.minimize();
    }
  }
}

final nativeFullscreen = ValueNotifier<bool>(false);
Future<void> _fullscreenQueue = Future<void>.value();

Future<void> setNativeFullscreen(bool value) {
  final transition = _fullscreenQueue.then((_) => _setNativeFullscreen(value));
  // A failed request must not prevent subsequent requests from recovering.
  _fullscreenQueue = transition.then<void>((_) {}, onError: (Object _) {});
  return transition;
}

Future<void> _setNativeFullscreen(bool value) async {
  if (await windowManager.isFullScreen() == value) {
    nativeFullscreen.value = value;
    return;
  }
  if (!Platform.isMacOS) {
    await windowManager.setFullScreen(value);
    // Windows does not emit leave-full-screen when returning to maximized.
    nativeFullscreen.value = await windowManager.isFullScreen();
    return;
  }
  final listener = _FullscreenTransitionListener(value);
  windowManager.addListener(listener);
  try {
    await windowManager.setFullScreen(value);
    await listener.completed.future.timeout(const Duration(seconds: 5));
    nativeFullscreen.value = await windowManager.isFullScreen();
  } finally {
    windowManager.removeListener(listener);
  }
}

class _FullscreenTransitionListener with WindowListener {
  final bool entering;
  _FullscreenTransitionListener(this.entering);
  final completed = Completer<void>();
  @override
  void onWindowEnterFullScreen() {
    if (entering && !completed.isCompleted) completed.complete();
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!entering && !completed.isCompleted) completed.complete();
  }
}
