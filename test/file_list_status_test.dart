import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/design.dart';

void main() {
  for (final grid in [false, true]) {
    testWidgets(
      'single file selection and playback indicators in ${grid ? 'grid' : 'list'}',
      (tester) async {
        var preview = 0, play = 0;
        String? menuAction;
        final rows = List.generate(
          4,
          (i) => <String, Object?>{
            'id': i + 1,
            'title': '영상 ${i + 1}',
            'folder': 'library',
            'type': 'video',
            'duration': 60.0,
            'online': 1,
            'rating': null,
            'play_count': i == 1 ? 2 : 0,
            'last_played': i == 2 ? 1 : 0,
            'resume_ms': i == 3 ? 5000 : 0,
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 310,
                  height: 600,
                  child: StatefulBuilder(
                    builder: (context, setState) => VaultFileList(
                      items: rows,
                      current: null,
                      grid: grid,
                      preview: (_) => preview++,
                      play: (_) => play++,
                      action: (_, action) => menuAction = action,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('01'), findsNothing);
        expect(
          tester
              .widget<Icon>(find.byKey(const ValueKey('file-playback-1')))
              .icon,
          Icons.play_circle_outline,
        );
        for (final id in [2, 3, 4]) {
          await tester.scrollUntilVisible(
            find.byKey(ValueKey('file-playback-$id')),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            tester.widget<Icon>(find.byKey(ValueKey('file-playback-$id'))).icon,
            Icons.play_circle_filled,
          );
        }
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.byTooltip('영상 1 선택'), findsNothing);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(find.text('영상 1'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(preview, 1);
        expect(play, 0);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(find.text('영상 1'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('영상 1'));
        await tester.pumpAndSettle();
        expect(play, 1);
        await tester.tap(find.byTooltip('파일 메뉴').first);
        await tester.pumpAndSettle();
        for (final label in ['여러 파일 선택', '재생', '정보 편집', '이름 변경']) {
          expect(find.text(label), findsNothing);
        }
        await tester.tap(find.text('상세정보'));
        await tester.pumpAndSettle();
        expect(menuAction, 'detail');
        await tester.tap(
          find.text('영상 1'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(find.text('상세정보'), findsOneWidget);
        for (final label in ['여러 파일 선택', '재생', '정보 편집', '이름 변경']) {
          expect(find.text(label), findsNothing);
        }
        await tester.tap(find.text('파일 이동'));
        await tester.pumpAndSettle();
        expect(menuAction, 'move');
        expect(preview, 1);
        expect(play, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'metadata stays in three rows with right aligned time and rating',
    (tester) async {
      const actor = '긴 배우 이름과 추가 배우';
      const tags = '#긴태그 · #추가태그';
      for (final width in [310.0, 400.0, 520.0]) {
        for (final scale in [1.0, 1.5]) {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    height: 300,
                    child: VaultFileList(
                      items: const [
                        {
                          'id': 1,
                          'title': '정렬 확인',
                          'folder': 'library',
                          'duration': 60,
                          'online': 1,
                          'actors': actor,
                          'tags': '긴태그,추가태그',
                          'rating': 4,
                        },
                      ],
                      current: 1,
                      grid: false,
                      preview: (_) {},
                      play: (_) {},
                      action: (_, _) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final time = tester.getRect(find.text('01:00 · library'));
          final stars = tester.getRect(find.byType(DeckStars));
          expect(
            time.right,
            closeTo(stars.right, 0.1),
            reason: 'width=$width scale=$scale',
          );
          expect(
            tester.getTopLeft(find.text(actor)).dx,
            tester.getTopLeft(find.text(tags)).dx + 16,
          );
          expect(tester.getTopLeft(find.text(actor)).dy, time.top);
          expect(stars.top, greaterThan(time.top));
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
