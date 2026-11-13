import 'support/file_navigation.dart';
import 'support/settings_navigation.dart';
import 'support/native_surface.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/main.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/settings_panel.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'reference content at both design sizes and edge-to-edge resize',
    (tester) async {
      MediaKit.ensureInitialized();
      await windowManager.ensureInitialized();
      await prepareNativeSurface(tester);
      await windowManager.setTitle('Soft Vault · E2E - design_parity_test');
      const repo = String.fromEnvironment('REPO_ROOT');
      const fixture = String.fromEnvironment('VIDEO_FIXTURE');
      final root = await Directory(
        await Directory.systemTemp.resolveSymbolicLinks(),
      ).createTemp('vault-design-');
      final source = await Directory(p.join(root.path, '작업 폴더')).create();
      final target = await Directory(p.join(root.path, '외장 SSD')).create();
      final library = await Library.open(p.join(root.path, 'db.sqlite'));
      final capture = GlobalKey();
      Future<void> shot(String name) async {
        for (final size in [const Size(1440, 900), const Size(1280, 800)]) {
          await resizeNativeSurface(tester, size);
          await tester.pumpAndSettle();
          expectNativeSurface(tester);
          expect(tester.takeException(), isNull);
          if (name.startsWith('design-settings')) {
            expect(find.byKey(const ValueKey('library-sidebar')), findsNothing);
            expect(
              tester.getSize(find.byType(SettingsPanel)).width,
              size.width,
            );
          } else {
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('library-sidebar')))
                  .width,
              size.width <= 1280 ? 512 : 576,
            );
          }
          if (name == 'design-library') {
            final sidebar = tester.getRect(
              find.byKey(const ValueKey('library-sidebar')),
            );
            expect(find.text('재생 대기 중'), findsOneWidget);
            expect(
              tester.getRect(find.text('재생 대기 중')).right,
              lessThan(sidebar.left),
            );
            expect(sidebar.right, size.width);
          }
          final boundary =
              capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          expect(boundary.size, size);
          expect(tester.getSize(find.byType(Scaffold).first), size);
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/e2e').create(recursive: true);
          await File(
            'build/e2e/$name-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        }
      }

      try {
        final rows =
            jsonDecode(
                  await File(
                    p.join(repo, 'test/fixtures/design-media.json'),
                  ).readAsString(),
                )
                as List;
        for (final row in rows) {
          await File(fixture).copy(
            p.join(
              row['folder'] == 'films' ? source.path : target.path,
              '${p.basenameWithoutExtension(row['file'] as String)}.mp4',
            ),
          );
        }
        await library.connect(source.path);
        await library.connect(target.path);
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i] as Map<String, dynamic>;
          final path = p.join(
            row['folder'] == 'films' ? source.path : target.path,
            '${p.basenameWithoutExtension(row['file'] as String)}.mp4',
          );
          final item = (await library.db.query(
            'media',
            where: 'path=?',
            whereArgs: [path],
          )).single;
          await library.edit(item['id'] as int, {
            'title': row['title'],
            'rating': row['rating'],
            'actors': (row['actors'] as List).join(', '),
            'tags': (row['tags'] as List).join(', '),
            'description': row['note'],
          });
          await library.db.update(
            'media',
            {
              'added': 100 - i,
              'duration': row['duration'],
              'codec': row['codec'],
              'resolution': row['resolution'],
              'thumbnail': p.join(repo, 'design/assets/${row['image']}.jpg'),
            },
            where: 'id=?',
            whereArgs: [item['id']],
          );
        }
        for (final entry in {
          '이서윤': 'Seoyun Lee',
          '김도현': 'Dohyun Kim',
          '박지우': 'Jiwoo Park',
        }.entries) {
          await library.db.update(
            'actors',
            {'alias': entry.value},
            where: 'name=?',
            whereArgs: [entry.key],
          );
        }
        await resizeNativeSurface(tester, const Size(1440, 900));
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: VaultApp(library: library),
          ),
        );
        await tester.pumpAndSettle();
        await shot('design-library');
        await openFileDetails(tester);
        await shot('design-detail');
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        for (final entry in {
          '배우': 'design-actors',
          '태그': 'design-tags',
        }.entries) {
          await tester.tap(find.text(entry.key).last);
          await shot(entry.value);
        }
        await openSettings(tester);
        await shot('design-settings');
        for (final entry in {
          '재생': 'playback',
          '단축키': 'shortcuts',
          '백업': 'backup',
        }.entries) {
          await tester.tap(
            find.byKey(ValueKey('settings-section-${entry.key}')),
          );
          await shot('design-settings-${entry.value}');
        }
        await tester.tap(find.text('영상으로 돌아가기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('검색 · Ctrl/Cmd+K'));
        await shot('design-search');
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        for (final size in [const Size(1000, 700), const Size(1600, 900)]) {
          await resizeNativeSurface(tester, size);
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(find.byType(Scaffold).first), Offset.zero);
          expect(tester.getSize(find.byType(Scaffold).first), size);
          expect(tester.takeException(), isNull);
        }
        for (final size in [
          const Size(1000, 700),
          const Size(1280, 800),
          const Size(1440, 900),
        ]) {
          await resizeNativeSurface(tester, size);
          for (final scale in [1.0, 1.25, 1.5]) {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'native layout scale=' + scale.toString(),
            );
          }
        }
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        // A 1080px-tall client cannot fit in a normal 1080px desktop window
        // with its title bar. Exercise real maximized/fullscreen dimensions.
        for (final change in <Future<void> Function()>[
          // Reproduce the reported 1000x700 OUTER window (984x661 client at
          // 100% Windows DPI), without fitting a fake 1000x700 canvas into it.
          () => windowManager.setSize(const Size(1000, 700)),
          () => windowManager.maximize(),
          () => setNativeFullscreen(true),
          () => setNativeFullscreen(false),
          () => windowManager.restore(),
        ]) {
          await change();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();
          expectNativeSurface(tester);
          final native = ui.PlatformDispatcher.instance.views.first;
          final client = native.physicalSize / native.devicePixelRatio;
          final scaffold = tester.getRect(find.byType(Scaffold).first);
          expect(scaffold, Offset.zero & client);
          final sidebarFinder = find.byKey(const ValueKey('library-sidebar'));
          if (await windowManager.isFullScreen()) {
            // Native fullscreen events now update the app layout as well.
            expect(sidebarFinder, findsNothing);
          } else {
            final sidebar = tester.getRect(sidebarFinder);
            expect(sidebar.right, scaffold.right);
            expect(sidebar.bottom, scaffold.bottom);
          }
          expect(tester.takeException(), isNull);
        }
      } finally {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await setNativeFullscreen(false);
        await windowManager.restore();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await library.close();
        await root.delete(recursive: true);
      }
    },
  );
}
