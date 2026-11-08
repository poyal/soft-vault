import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'playback.dart';

class NativePlayback implements PlaybackPort {
  final Player player;
  NativePlayback(this.player);
  @override
  Future<void> volume(double value) => player.setVolume(value);
  @override
  Future<void> openPaused(String path, {Duration start = Duration.zero}) =>
      player.open(Media(path, start: start), play: false);
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
        final listener = _FullscreenExitListener();
        windowManager.addListener(listener);
        try {
          await windowManager.setFullScreen(false);
          await listener.exited.future.timeout(const Duration(seconds: 5));
        } finally {
          windowManager.removeListener(listener);
        }
      }
      await windowManager.minimize();
    }
  }
}

class _FullscreenExitListener with WindowListener {
  final exited = Completer<void>();
  @override
  void onWindowLeaveFullScreen() {
    if (!exited.isCompleted) exited.complete();
  }
}
