import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/library_filter.dart';
import 'package:soft_vault/library_filter_dialog.dart';

void main() {
  final entries = List.generate(
    1000,
    (i) => <String, Object?>{
      'id': i + 1,
      'name': i == 0 ? '긴 이름 ' * 40 : '배우 $i',
      'alias': '별칭$i',
    },
  );
  testWidgets('draft stars, alias search, lazy lists, apply and cancel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    LibraryFilter? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<LibraryFilter>(
                  context: context,
                  builder: (_) => LibraryFilterDialog(
                    initial: LibraryFilter(),
                    actors: entries,
                    tags: entries,
                  ),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('filter-star-4')));
    await tester.tap(find.byKey(const ValueKey('filter-star-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정확히'));
    await tester.tap(find.text('정확히'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile).evaluate().length, lessThan(50));
    await tester.ensureVisible(find.byKey(const ValueKey('배우-search')));
    await tester.enterText(find.byKey(const ValueKey('배우-search')), '별칭999');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('배우-1000')));
    await tester.tap(find.byKey(const ValueKey('배우-1000')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(result!.rating, 4);
    expect(result!.exact, true);
    expect(result!.actorIds, [1000]);
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('미평가'));
    await tester.tap(find.text('미평가'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets(
    'long selections fit minimum size, stale IDs cleaned, reset stays draft',
    (tester) async {
      for (final size in [const Size(1000, 700), const Size(1440, 900)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            home: LibraryFilterDialog(
              key: ValueKey(size),
              initial: LibraryFilter(actorIds: [1, 9999], tagIds: [1]),
              actors: entries,
              tags: entries,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('삭제된 배우·태그를 선택 조건에서 제외했습니다.'), findsOneWidget);
        await tester.tap(find.text('필터 초기화'));
        await tester.pumpAndSettle();
        expect(find.text('배우 · 0개 선택'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
