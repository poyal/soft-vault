import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/file_list.dart';

void main() {
  for (final grid in [false, true]) {
    testWidgets(
      'top selection and playback indicators in ${grid ? 'grid' : 'list'}',
      (tester) async {
        final selected = <int>{};
        var preview = 0, play = 0;
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
                      selected: selected,
                      current: null,
                      grid: grid,
                      toggle: (id) => setState(() {
                        if (!selected.add(id)) selected.remove(id);
                      }),
                      preview: (_) => preview++,
                      play: (_) => play++,
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
        final check = find.byTooltip('영상 1 선택');
        expect(
          tester.getTopLeft(check).dy,
          lessThan(
            tester.getTopLeft(find.byKey(const ValueKey('file-playback-1'))).dy,
          ),
        );
        await tester.tap(check);
        await tester.pump();
        expect(selected, {1});
        expect(preview, 0);
        expect(play, 0);
        await tester.tap(check);
        await tester.pump();
        expect(selected, isEmpty);
        await tester.pump(const Duration(milliseconds: 350));
        expect(preview, 0);
        expect(play, 0);
        await tester.tap(find.text('영상 1'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('영상 1'));
        await tester.pumpAndSettle();
        expect(play, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
