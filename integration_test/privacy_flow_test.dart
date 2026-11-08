import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/main.dart';
import 'package:soft_vault/hover_preview.dart';
import 'package:soft_vault/player_controls.dart';
import 'package:soft_vault/privacy_lock.dart';
import 'package:window_manager/window_manager.dart';
import 'support/native_surface.dart';
import 'support/scenario_app.dart';
import 'support/settings_navigation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const password = 'E2E privacy password 123';
  const replacement = 'E2E replacement password 456';
  final results = <Map<String, Object?>>[];

  Future<void> scenario(
    String name,
    WidgetTester tester,
    Future<void> Function(
      ScenarioApp,
      PrivacyLock,
      Future<void> Function(),
      Future<void> Function(String),
      int Function(),
    )
    action,
  ) async {
    final app = await ScenarioApp.create(tester, fixtures: 1);
    final privacy = PrivacyLock(p.join(app.root.path, 'privacy.sqlite'));
    final capture = GlobalKey();
    var opens = 0;
    final watch = Stopwatch()..start();
    Future<void> mount() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await privacy.close();
      await setNativeFullscreen(false);
      await windowManager.restore();
      await windowManager.setPreventClose(false);
      await windowManager.setTitle('Soft Vault · E2E - $name');
      await resizeNativeSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: VaultApp(
            privacy: privacy,
            loadLibrary: () async {
              opens++;
              return app.library;
            },
          ),
        ),
      );
      await app.settle();
    }

    Future<void> shot(String label) async {
      await app.settle();
      expectNativeSurface(tester);
      final boundary =
          capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/e2e/privacy-$label-1280.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    try {
      await action(app, privacy, mount, shot, () => opens);
      results.add({
        'name': name,
        'passed': true,
        'ms': watch.elapsedMilliseconds,
      });
      await File(
        'build/e2e/privacy-results.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    } catch (_) {
      await shot('failure');
      debugPrint(
        'Privacy E2E visible text: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(' | ')}',
      );
      debugPrint(
        'Privacy E2E home elements: ${find.byType(VaultHome, skipOffstage: false).evaluate().length}',
      );
      rethrow;
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await privacy.close();
      await app.close();
    }
  }

  Future<void> input(WidgetTester tester, String key, String value) async {
    final field = find.byKey(ValueKey(key));
    await tester.tap(field);
    await tester.pump();
    // Keep the real Windows text-input connection synchronized. TestTextInput's
    // fake client can replay an old value when the same secure field is edited.
    // OS keyboard/IME is outside this test; submission reads this real controller.
    tester.widget<TextField>(field).controller!.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('privacy-submit')));
    await tester.pump();
  }

  Future<void> unlock(ScenarioApp app, String value) async {
    await input(app.tester, 'privacy-current', value);
    await submit(app.tester);
    await app.until(() => find.byType(VaultHome).evaluate().isNotEmpty);
    await app.settle();
  }

  testWidgets(
    'PRIVACY-01 startup gate, password management and silent manual lock',
    (tester) => scenario('PRIVACY-01', tester, (
      app,
      privacy,
      mount,
      shot,
      opens,
    ) async {
      await mount();
      expect(find.byType(VaultHome), findsNothing);
      expect(opens(), 0);
      await shot('setup');
      await input(tester, 'privacy-new', password);
      await input(tester, 'privacy-confirm', 'not matching');
      await submit(tester);
      await app.settle();
      expect(find.text('새 비밀번호가 서로 다릅니다.'), findsOneWidget);
      expect(opens(), 0);
      await input(tester, 'privacy-confirm', password);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('privacy-new')))
            .controller!
            .text,
        password,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('privacy-confirm')))
            .controller!
            .text,
        password,
      );
      final setup = Stopwatch()..start();
      await submit(tester);
      await app.until(() => find.byType(VaultHome).evaluate().isNotEmpty);
      results.add({
        'name': 'password setup latency',
        'passed': true,
        'ms': setup.elapsedMilliseconds,
      });
      await mount();
      final before = opens();
      expect(find.byType(VaultHome), findsNothing);
      expect(find.text('나중에 설정'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await app.settle();
      expect(find.byType(VaultHome), findsNothing);
      expect(await windowManager.isFullScreen(), isFalse);
      await input(tester, 'privacy-current', 'wrong password');
      await submit(tester);
      await app.until(() => find.text('비밀번호가 맞지 않습니다.').evaluate().isNotEmpty);
      expect(opens(), before);
      await shot('locked');
      await unlock(app, password);
      await tester.tap(find.byType(HoverPreview).first);
      await app.until(
        () => find.byType(PlaybackControls).evaluate().isNotEmpty,
      );
      final player = app.player;
      await player.setVolume(25);
      await openSettings(tester, '사생활 보호');
      await app.until(() => find.text('비밀번호 보호 켜짐').evaluate().isNotEmpty);
      await shot('settings');
      await tester.tap(find.text('지금 잠그기'));
      await app.until(
        () => find.byKey(const ValueKey('privacy-gate')).evaluate().isNotEmpty,
      );
      expect(player.state.volume, 0);
      expect(player.state.playing, isFalse);
      expect(find.byType(PlaybackControls), findsNothing);
      await unlock(app, password);
      await openSettings(tester, '사생활 보호');
      await tester.tap(find.text('비밀번호 변경'));
      await app.settle();
      await input(tester, 'privacy-current', password);
      await input(tester, 'privacy-new', replacement);
      await input(tester, 'privacy-confirm', replacement);
      await submit(tester);
      await app.until(() => find.text('잠금 설정을 저장했습니다.').evaluate().isNotEmpty);
      await mount();
      await input(tester, 'privacy-current', password);
      await submit(tester);
      await app.until(() => find.text('비밀번호가 맞지 않습니다.').evaluate().isNotEmpty);
      await unlock(app, replacement);
      await openSettings(tester, '사생활 보호');
      await tester.tap(find.text('잠금 기능 끄기'));
      await app.settle();
      await input(tester, 'privacy-current', 'incorrect');
      await submit(tester);
      await app.until(() => find.text('비밀번호가 맞지 않습니다.').evaluate().isNotEmpty);
      expect((await privacy.status()).enabled, isTrue);
      await input(tester, 'privacy-current', replacement);
      await submit(tester);
      await app.until(() => find.text('비밀번호 보호 꺼짐').evaluate().isNotEmpty);
      await mount();
      await app.until(() => find.byType(VaultHome).evaluate().isNotEmpty);
      expect(find.byKey(const ValueKey('privacy-gate')), findsNothing);
    }),
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'PRIVACY-02 cooldown survives app restart and blocks UI submission',
    (tester) => scenario('PRIVACY-02', tester, (
      app,
      privacy,
      mount,
      shot,
      opens,
    ) async {
      await privacy.setPassword(password);
      await mount();
      for (var i = 0; i < 5; i++) {
        await input(tester, 'privacy-current', 'wrong-$i');
        await submit(tester);
        await app.until(
          () => find.text('비밀번호가 맞지 않습니다.').evaluate().isNotEmpty,
        );
      }
      expect(opens(), 0);
      await mount();
      await app.settle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('privacy-submit')))
            .onPressed,
        isNull,
      );
      expect(find.byType(VaultHome), findsNothing);
      expect(opens(), 0);
      await shot('cooldown');
    }),
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'PRIVACY-03 damaged protection data never opens the catalog',
    (tester) => scenario('PRIVACY-03', tester, (
      app,
      privacy,
      mount,
      shot,
      opens,
    ) async {
      await privacy.setPassword(password);
      await (await privacy.database).update('app_lock', {
        'verifier': 'invalid',
      });
      await mount();
      expect(find.text('잠금 정보를 읽을 수 없어 앱을 열지 않았습니다.'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      await app.settle();
      expect(opens(), 0);
      expect(find.byType(VaultHome), findsNothing);
      expect(find.text('나중에 설정'), findsNothing);
      await shot('storage-error');
    }),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
