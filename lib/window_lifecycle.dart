import 'dart:io';
import 'package:window_manager/window_manager.dart';

/// Call after saving state and releasing the player.
Future<void> closeAppWindow() async {
  if (Platform.isWindows) {
    // destroy() posts WM_QUIT directly. WM_CLOSE must run first so the Flutter
    // controller is destroyed while its window and COM are still alive.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  } else {
    await windowManager.destroy();
  }
}
