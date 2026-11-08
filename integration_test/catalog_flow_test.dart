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
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/search_dialog.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'catalog screens, batch editing, physical move and shortcut settings',
    (tester) async {
      MediaKit.ensureInitialized();
      await windowManager.ensureInitialized();
      await prepareNativeSurface(tester);
      await windowManager.setTitle('Soft Vault · E2E - catalog_flow_test');
      final root = await Directory(
        await Directory.systemTemp.resolveSymbolicLinks(),
      ).createTemp('vault-catalog-e2e-');
      final source = await Directory(p.join(root.path, '작업 폴더')).create();
      final destination = await Directory(p.join(root.path, '선택 폴더')).create();
      const fixture = String.fromEnvironment('VIDEO_FIXTURE');
      final titles = [
        '북쪽으로 향하는 길',
        '고요를 따라',
        '숲이 건네는 이야기',
        '아주 긴 파일 이름과 한글 日本語 🎬 테스트',
      ];
      for (var index = 0; index < titles.length; index++) {
        await File(fixture).copy(p.join(source.path, '${titles[index]}.mp4'));
      }
      final library = await Library.open(p.join(root.path, 'db.sqlite'));
      final capture = GlobalKey();
      Future<void> shot(String name) async {
        for (final size in [const Size(1440, 900), const Size(1280, 800)]) {
          await resizeNativeSurface(tester, size);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final boundary =
              capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          expectNativeSurface(tester);
          final rendered = await boundary.toImage(pixelRatio: 1);
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await Directory('build/e2e').create(recursive: true);
          await File(
            'build/e2e/${name.replaceFirst(RegExp(r'-(1280|1440)$'), '')}-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        }
      }

      try {
        await library.connect(source.path);
        await library.connect(destination.path);
        final rows = await library.items();
        for (final row in rows) {
          await library.edit(row['id'] as int, {
            'rating': 4,
            'actors': '이서윤',
            'tags': '여행, 자연',
            'description':
                '아침 안개가 걷히고, 산맥 위로 빛이 들어오는 순간.\n다시 보고 싶은 장면들을 담았습니다.',
          });
        }
        await resizeNativeSurface(tester, const Size(1440, 900));
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: VaultApp(library: library),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('북쪽으로 향하는 길').last);
        await shot('01-library-1440');
        await resizeNativeSurface(tester, const Size(1280, 800));
        await shot('01-library-1280');
        await settingsAction(tester, '썸네일 · 목록 보기');
        await shot('01-grid-1280');
        await settingsAction(tester, '썸네일 · 목록 보기');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('상세정보 보기'));
        await shot('03-detail-1280');
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('배우').last);
        await shot('04-actors-1280');
        await tester.tap(find.text('배우 추가'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '새 배우');
        await tester.enterText(find.byType(TextField).at(1), 'Alias');
        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();
        expect((await library.entities('actors')).length, 2);
        await tester.tap(find.text('태그').last);
        await shot('05-tags-1280');
        await tester.tap(find.text('파일'));
        await tester.pumpAndSettle();
        await openSettings(tester);
        await tester.tap(find.text('연결 폴더 관리'));
        await shot('06-folders-1280');
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        await settingsAction(tester, '전체 선택');
        await shot('12-selection-1280');
        await tester.tap(find.text('태그 편집'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '일괄 태그');
        await tester.tap(find.text('적용'));
        await tester.pumpAndSettle();
        expect((await library.items(query: '일괄 태그')).length, 4);
        await tester.tap(find.text('폴더 이동'));
        await shot('07-move-1280');
        await tester.tap(
          find.byKey(ValueKey('move-target:${destination.path}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '이동'));
        await tester.pumpAndSettle();
        for (var tries = 0; tries < 80; tries++) {
          if ((await library.items()).every(
            (row) => row['folder'] == destination.path,
          ))
            break;
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          (await library.items()).every(
            (row) => row['folder'] == destination.path,
          ),
          isTrue,
        );
        expect(await source.list().isEmpty, isTrue);
        await shot('07-move-complete-1280');
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('선택 해제'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('검색 · Ctrl/Cmd+K'));
        await shot('08-search-1280');
        final firstSearchResult = (await library.items(
          limit: 3,
        )).first['title'];
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        final picked = tester
            .widgetList<ListTile>(
              find.descendant(
                of: find.byType(LibrarySearchDialog),
                matching: find.byType(ListTile),
              ),
            )
            .where((tile) => tile.selected)
            .single;
        expect((picked.title as Text).data, firstSearchResult);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(LibrarySearchDialog), findsNothing);
        await tester.tap(find.byTooltip('검색 · Ctrl/Cmd+K'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '없는 결과');
        await tester.tap(find.widgetWithText(TextButton, '검색'));
        await shot('13-no-results-1280');
        await openSettings(tester, '단축키');
        await shot('09-settings-1280');
        await tester.tap(find.text('Space').first);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
        await tester.pumpAndSettle();
        expect(find.textContaining('사용 중입니다.'), findsOneWidget);
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await library.close();
        await root.delete(recursive: true);
      }
    },
  );
}
