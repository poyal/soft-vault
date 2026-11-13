import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soft_vault/detail_dialog.dart';
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/library_filter.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/player_controls.dart';
import 'support/scenario_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('menu details edit and rename only the targeted file', (
    tester,
  ) async {
    final app = await ScenarioApp.create(tester);
    try {
      await app.mount();
      final dynamic home = tester.state(find.byType(VaultHome));
      final rows = app.visible;
      final target = rows.last;
      final other = rows.first;
      await home.select(other);
      await tester.tap(find.byTooltip('파일 메뉴').last);
      await app.settle();
      for (final removed in ['여러 파일 선택', '재생', '정보 편집', '이름 변경']) {
        expect(find.text(removed), findsNothing);
      }
      await app.tap('상세정보');
      expect(
        tester.widget<DetailEditor>(find.byType(DetailEditor)).item['id'],
        target['id'],
      );
      await app.tap('정보 편집');
      await tester.enterText(find.byType(TextField).first, '취소할 제목');
      await app.tap('취소');
      expect(
        (await app.library.items()).firstWhere(
          (r) => r['id'] == target['id'],
        )['title'],
        target['title'],
      );

      await tester.tap(find.byTooltip('파일 메뉴').last);
      await app.settle();
      await app.tap('상세정보');
      await app.tap('정보 편집');
      await tester.enterText(find.byType(TextField).first, '저장한 표시 제목');
      await tester.enterText(find.byType(TextField).at(1), '검증 배우');
      await tester.enterText(find.byType(TextField).at(2), '검증 태그');
      await app.tap('저장');
      var saved = (await app.library.items()).firstWhere(
        (r) => r['id'] == target['id'],
      );
      expect(saved['title'], '저장한 표시 제목');
      expect(saved['path'], target['path']);
      expect(saved['actors'], '검증 배우');
      expect(saved['tags'], '검증 태그');

      home.edit(mediaId: target['id'] as int);
      await app.settle();
      await app.tap('이름 변경');
      expect(find.text('파일 이름 변경'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'cancelled.mp4');
      await app.tap('닫기');
      expect(await File(target['path'] as String).exists(), isTrue);
      home.edit(mediaId: target['id'] as int);
      await app.settle();
      await app.tap('이름 변경');
      await tester.enterText(find.byType(TextField).first, 'renamed.mp4');
      await tester.tap(find.widgetWithText(FilledButton, '이름 변경'));
      await app.settle();
      await app.until(() => find.text('닫기').evaluate().isNotEmpty);
      saved = (await app.library.items()).firstWhere(
        (r) => r['id'] == target['id'],
      );
      expect(saved['path'], endsWith('renamed.mp4'));
      expect(await File(saved['path'] as String).exists(), isTrue);
      expect(await File(target['path'] as String).exists(), isFalse);
      expect(saved['title'], '저장한 표시 제목');
      expect(saved['actors'], '검증 배우');
      expect(saved['tags'], '검증 태그');
      expect(
        (await app.library.items()).firstWhere(
          (r) => r['id'] == other['id'],
        )['path'],
        other['path'],
      );
      await app.tap('닫기');
    } finally {
      await app.close();
    }
  });

  testWidgets('playback ratings survive filters, errors, switching and remount', (
    tester,
  ) async {
    final app = await ScenarioApp.create(tester);
    try {
      final rows = await app.library.items();
      final first = rows.first, second = rows.last;
      await app.library.edit(first['id'] as int, {'rating': 4});
      await app.library.edit(second['id'] as int, {'rating': 1});
      await app.mount();
      dynamic home = tester.state(find.byType(VaultHome));
      await tester.tap(find.byTooltip('정렬'));
      await app.settle();
      await app.tap('이름순');
      expect(home.sort, 'name');
      expect(
        app.visible.map((r) => r['id']),
        (await app.library.items(sort: 'name')).map((r) => r['id']),
      );
      tester.widget<VaultFileList>(find.byType(VaultFileList)).play(first);
      await app.until(() => home.playbackMediaId == first['id']);
      await app.settle();
      await home.select(second);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await app.settle();
      expect(
        (await app.library.items()).firstWhere(
          (r) => r['id'] == first['id'],
        )['rating'],
        5,
      );
      expect(
        (await app.library.items()).firstWhere(
          (r) => r['id'] == second['id'],
        )['rating'],
        1,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await app.settle();
      expect(
        tester.widget<PlaybackControls>(find.byType(PlaybackControls)).rating,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await app.settle();
      home.libraryFilter = LibraryFilter(rating: 4);
      await home.refresh();
      await app.settle();
      expect(find.text('필터 해제'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(PlaybackControls),
          matching: find.byTooltip('2점'),
        ),
      );
      await app.settle();
      expect(app.visible, isEmpty);
      expect(
        tester.widget<PlaybackControls>(find.byType(PlaybackControls)).rating,
        2,
      );
      await app.tap('필터 해제');
      expect(app.visible.length, 2);

      await app.library.db.execute(
        "CREATE TEMP TRIGGER reject_rating BEFORE UPDATE OF rating ON media BEGIN SELECT RAISE(ABORT, 'rating-save-test'); END",
      );
      await tester.tap(
        find.descendant(
          of: find.byType(PlaybackControls),
          matching: find.byTooltip('5점'),
        ),
      );
      await app.settle();
      expect(
        tester.widget<PlaybackControls>(find.byType(PlaybackControls)).rating,
        2,
      );
      expect(home.error, contains('rating-save-test'));
      await app.library.db.execute('DROP TRIGGER reject_rating');
      tester.widget<PlaybackControls>(find.byType(PlaybackControls)).rate!(3);
      tester.widget<VaultFileList>(find.byType(VaultFileList)).play(second);
      await app.until(() => home.playbackMediaId == second['id']);
      await app.settle();
      expect(
        tester.widget<PlaybackControls>(find.byType(PlaybackControls)).rating,
        1,
      );
      expect(
        (await app.library.items()).firstWhere(
          (r) => r['id'] == first['id'],
        )['rating'],
        3,
      );
      expect(
        (await app.library.items()).firstWhere(
          (r) => r['id'] == second['id'],
        )['rating'],
        1,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final databasePath = app.library.db.path;
      await app.library.close();
      final reopened = await Library.open(databasePath);
      try {
        expect(
          (await reopened.items()).firstWhere(
            (r) => r['id'] == first['id'],
          )['rating'],
          3,
        );
        await tester.pumpWidget(VaultApp(library: reopened));
        await app.settle(15);
        home = tester.state(find.byType(VaultHome));
        tester.widget<VaultFileList>(find.byType(VaultFileList)).play(first);
        await app.until(() => home.playbackMediaId == first['id']);
        await app.settle();
        expect(
          tester.widget<PlaybackControls>(find.byType(PlaybackControls)).rating,
          3,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await reopened.close();
      }
    } finally {
      await app.close();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
