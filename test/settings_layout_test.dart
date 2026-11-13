import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soft_vault/library.dart';
import 'package:soft_vault/key_bindings.dart';
import 'package:soft_vault/settings_panel.dart';

void main() {
  testWidgets('all settings sections fit desktop sizes and retain navigation', (
    tester,
  ) async {
    if (Platform.isWindows) {
      await tester.runAsync(() async {
        final loader = FontLoader('Segoe UI');
        loader.addFont(
          File(
            'C:/Windows/Fonts/malgun.ttf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
        await loader.load();
      });
    }
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('settings-layout-'),
    ))!;
    final library = (await tester.runAsync(
      () => Library.open('${root.path}/catalog.sqlite'),
    ))!;
    final keys = KeyBindings(library);
    await tester.runAsync(keys.load);
    final capture = GlobalKey();
    try {
      for (final scale in [1.0, 1.25, 1.5]) {
        for (final size in [
          const Size(1000, 700),
          const Size(1280, 800),
          const Size(1440, 900),
          const Size(1920, 1080),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              theme: ThemeData(
                brightness: Brightness.dark,
                fontFamily: 'Segoe UI',
                scaffoldBackgroundColor: const Color(0xff15191e),
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xff87b8d8),
                  surface: Color(0xff1c2229),
                ),
              ),
              home: Scaffold(
                body: RepaintBoundary(
                  key: capture,
                  child: SettingsPanel(
                    keys: keys,
                    folderCount: 3,
                    mediaTitle: '긴 영상 이름 ' * 20,
                    busy: false,
                    connect: () {},
                    folders: () {},
                    action: (_) {},
                    close: () {},
                    capturing: (_) {},
                    backup: () {},
                    restore: () {},
                    external: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();
          for (final section in [
            '라이브러리',
            '재생',
            '단축키',
            '메타데이터',
            '사생활 보호',
            '백업',
            '앱 정보 · 업데이트',
          ]) {
            await tester.tap(find.byKey(ValueKey('settings-section-$section')));
            await tester.pump();
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await tester.pumpAndSettle();
            expect(find.text('전체 선택'), findsNothing);
            expect(tester.takeException(), isNull, reason: '$size $section');
            if (size.width == 1280 && scale == 1)
              await tester.runAsync(() async {
                final image =
                    await (capture.currentContext!.findRenderObject()
                            as RenderRepaintBoundary)
                        .toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(
                  'build/settings-review',
                ).create(recursive: true);
                await File(
                  'build/settings-review/$section.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
          }
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
      await tester.runAsync(() async {
        await library.close();
        await root.delete(recursive: true);
      });
    }
  });
}
