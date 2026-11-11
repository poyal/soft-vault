import 'support/native_surface.dart';
import 'support/settings_navigation.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/player_controls.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('app keyboard, fullscreen, decoder state and offline screens', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    await windowManager.ensureInitialized();
    await prepareNativeSurface(tester);
    await windowManager.setTitle('Soft Vault · E2E - app_playback_test');
    const fixture = String.fromEnvironment('VIDEO_FIXTURE');
    final root = await Directory(
      await Directory.systemTemp.resolveSymbolicLinks(),
    ).createTemp('vault-app-e2e-');
    final source = await Directory(p.join(root.path, 'media')).create();
    final library = await Library.open(p.join(root.path, 'db.sqlite'));
    final capture = GlobalKey();
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    }

    Future<void> key(LogicalKeyboardKey value) async {
      debugPrint('E2E key start: ${value.keyLabel}');
      await tester.sendKeyEvent(value);
      debugPrint('E2E key dispatched: ${value.keyLabel}');
      if (value == LogicalKeyboardKey.escape) {
        await waitNativeMinimized(tester);
      } else {
        await settle();
      }
      debugPrint('E2E key complete: ${value.keyLabel}');
    }

    Future<void> shot(String name) async {
      final fullscreen = await windowManager.isFullScreen();
      final native = ui.PlatformDispatcher.instance.views.first;
      final sizes = fullscreen
          ? [native.physicalSize / native.devicePixelRatio]
          : [const Size(1440, 900), const Size(1280, 800)];
      for (final size in sizes) {
        if (!fullscreen) await resizeNativeSurface(tester, size);
        await settle();
        final boundary =
            capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
        expectNativeSurface(tester);
        final rendered = await boundary.toImage(pixelRatio: 1);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/e2e').create(recursive: true);
        await File(
          'build/e2e/$name-${fullscreen ? 'native' : size.width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      }
    }

    try {
      await restoreNativeWindow(tester);
      await setNativeFullscreen(false);
      await resizeNativeSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: VaultApp(library: library),
        ),
      );
      await settle();
      await shot('10-empty');
      await tester.tap(find.byTooltip('시작 안내 닫기'));
      await settle();
      await File(fixture).copy(p.join(source.path, 'keyboard-fixture.mp4'));
      await library.connect(source.path);
      await settingsAction(tester, '다시 검색');
      await settle();
      for (
        var i = 0;
        i < 100 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await key(LogicalKeyboardKey.space);
      final player = tester
          .widget<PlaybackControls>(find.byType(PlaybackControls))
          .player;
      expect(player.state.playing, isTrue);
      expect(player.state.volume, 0);
      await tester
          .widget<Video>(find.byType(Video))
          .controller
          .waitUntilFirstFrameRendered
          .timeout(const Duration(seconds: 15));
      expect(player.state.videoParams.dw, greaterThan(0));
      await key(LogicalKeyboardKey.space);
      expect(player.state.playing, isFalse);
      await key(LogicalKeyboardKey.keyW);
      expect(player.state.volume, 5);
      await key(LogicalKeyboardKey.keyM);
      expect(
        tester.widget<PlaybackControls>(find.byType(PlaybackControls)).muted,
        isTrue,
      );
      await key(LogicalKeyboardKey.keyW);
      expect(player.state.volume, 10);
      expect(
        tester.widget<PlaybackControls>(find.byType(PlaybackControls)).muted,
        isFalse,
      );
      await key(LogicalKeyboardKey.digit0);
      expect(player.state.volume, 0);
      final volumeSlider = find
          .descendant(
            of: find.byType(PlaybackControls),
            matching: find.byType(Slider),
          )
          .last;
      await tester.tap(volumeSlider);
      await settle();
      final volumeBeforeSeek = player.state.volume;
      final focusBeforeSeek = FocusManager.instance.primaryFocus;
      await key(LogicalKeyboardKey.arrowRight);
      expect(player.state.volume, volumeBeforeSeek);
      expect(FocusManager.instance.primaryFocus, same(focusBeforeSeek));
      expect(player.state.position.inSeconds, greaterThanOrEqualTo(4));
      await key(LogicalKeyboardKey.bracketRight);
      expect(player.state.rate, 1.25);
      await key(LogicalKeyboardKey.backspace);
      expect(player.state.rate, 1);
      await key(LogicalKeyboardKey.digit5);
      expect((await library.items()).single['rating'], 5);
      await shot('02-player');
      await resizeNativeSurface(tester, const Size(1000, 700));
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      await settle();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await resizeNativeSurface(tester, const Size(1280, 800));
      await settle();
      await key(LogicalKeyboardKey.keyF);
      expect(await windowManager.isFullScreen(), isTrue);
      expect(find.byTooltip('연결 폴더 관리'), findsNothing);
      await shot('02-fullscreen');
      await key(LogicalKeyboardKey.escape);
      await restoreNativeWindow(tester);
      await settle();
      expect(await windowManager.isFullScreen(), !Platform.isMacOS);
      expect(player.state.volume, 0);
      expect(player.state.playing, isFalse);
      if (Platform.isMacOS) {
        await key(LogicalKeyboardKey.keyF);
        expect(await windowManager.isFullScreen(), isTrue);
      }
      await key(LogicalKeyboardKey.keyF);
      expect(await windowManager.isFullScreen(), isFalse);
      await settingsAction(tester, '음성 · 자막 · 디코더');
      await settle();
      await tester.tap(find.byType(SwitchListTile));
      await settle();
      await tester.tap(find.text('닫기'));
      await settle();
      await settingsAction(tester, '음성 · 자막 · 디코더');
      await settle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await shot('02-decoder');
      await tester.tap(find.text('닫기'));
      await settle();
      await tester.tap(find.byTooltip('상세정보 보기'));
      await settle();
      await tester.tap(find.text('정보 편집'));
      await settle();
      await tester.enterText(find.byType(TextField).first, '한글 입력 123');
      await key(LogicalKeyboardKey.digit1);
      expect((await library.items()).single['rating'], 5);
      await key(LogicalKeyboardKey.escape);
      expect(await windowManager.isMinimized(), isTrue);
      await restoreNativeWindow(tester);
      await settle();
      if (find.text('한글 입력 123').evaluate().isEmpty) {
        await shot('edit-panic-failure');
        debugPrint(
          'Text fields after restore: ${tester.widgetList<TextField>(find.byType(TextField)).map((field) => field.controller?.text).toList()}',
        );
      }
      expect(find.text('한글 입력 123'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await settle();
      await player.stop();
      await library.disconnect(source.path);
      await settingsAction(tester, '다시 검색');
      await settle();
      await shot('11-offline');
      expect((await library.items()).single['online'], 0);
    } finally {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      debugPrint('E2E playback cleanup');
      await setNativeFullscreen(false);
      await restoreNativeWindow(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await library.close();
      await root.delete(recursive: true);
    }
  });
}
