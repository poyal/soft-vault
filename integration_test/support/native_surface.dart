import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

/// A minimized macOS window has no vsync; pumping a frame can wait forever.
Future<void> waitNativeMinimized(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 70 && !await windowManager.isMinimized(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(await windowManager.isMinimized(), isTrue);
  });
}

Future<void> restoreNativeWindow(WidgetTester tester) async {
  await tester.runAsync(() async {
    await windowManager.restore();
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
}

/// Resize the real client area, accounting for the Windows title bar/borders.
/// setSurfaceSize would fit a fake canvas into that area and add letterboxing.
Future<void> resizeNativeSurface(
  WidgetTester tester,
  ui.Size clientSize,
) async {
  expect(
    await windowManager.isFullScreen(),
    isFalse,
    reason: 'Capture fullscreen at native resolution instead of resizing it',
  );
  for (var attempt = 0; attempt < 4; attempt++) {
    final view = ui.PlatformDispatcher.instance.views.first;
    final actual = view.physicalSize / view.devicePixelRatio;
    final deltaWidth = clientSize.width - actual.width;
    final deltaHeight = clientSize.height - actual.height;
    if (deltaWidth.abs() < .01 && deltaHeight.abs() < .01) break;
    final outer = await windowManager.getSize();
    await windowManager.setSize(
      ui.Size(outer.width + deltaWidth, outer.height + deltaHeight),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  final view = ui.PlatformDispatcher.instance.views.first;
  expect(view.physicalSize / view.devicePixelRatio, clientSize);
  expectNativeSurface(tester);
}

/// Offscreen screenshots alone cannot prove the desktop compositor receives
/// a valid frame. Never fake native physical size/DPI in desktop E2E tests.
void expectNativeSurface(WidgetTester tester) {
  for (final renderView in tester.binding.renderViews) {
    final native = ui.PlatformDispatcher.instance.views.singleWhere(
      (view) => view.viewId == renderView.flutterView.viewId,
    );
    expect(
      renderView.configuration.toPhysicalSize(renderView.size),
      native.physicalSize,
      reason: 'Submitted frame must match the real Windows client surface',
    );
    expect(
      renderView.configuration.devicePixelRatio,
      native.devicePixelRatio,
      reason: 'Desktop E2E must keep the actual display DPI',
    );
    expect(
      renderView.size,
      native.physicalSize / native.devicePixelRatio,
      reason:
          'Logical layout must fill the client, without a fitted test canvas',
    );
    final matrix = renderView.configuration.toMatrix();
    expect(matrix.storage[0], closeTo(native.devicePixelRatio, .00001));
    expect(matrix.storage[5], closeTo(native.devicePixelRatio, .00001));
    expect(matrix.storage[12], closeTo(0, .00001), reason: 'No side letterbox');
    expect(
      matrix.storage[13],
      closeTo(0, .00001),
      reason: 'No top/bottom letterbox',
    );
  }
}
