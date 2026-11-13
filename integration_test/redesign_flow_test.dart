import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/detail_dialog.dart';
import 'package:soft_vault/player_controls.dart';
import 'package:soft_vault/desktop_files.dart';
import 'support/scenario_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('0.3.1 real playback, details and native recycle', (
    tester,
  ) async {
    final app = await ScenarioApp.create(tester);
    Future<void> shot(String name, Finder target) async {
      final boundary = find
          .ancestor(of: target, matching: find.byType(RepaintBoundary))
          .first;
      final image = await tester
          .renderObject<RenderRepaintBoundary>(boundary)
          .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/review-031').create(recursive: true);
      await File(
        'build/review-031/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    }

    try {
      await app.mount();
      final dynamic home = tester.state(find.byType(VaultHome));
      final rows = await app.library.items();
      final first = rows.first;
      await app.library.edit(first['id'] as int, {
        'title': 'DEMO-001 · Actor',
        'actors': 'Actor',
        'tags': 'Sample, Test',
      });
      await home.refresh();
      await app.settle();
      expect(find.text('재생 대기 중'), findsOneWidget);
      await shot('library', find.byType(VaultFileList));
      tester.widget<VaultFileList>(find.byType(VaultFileList)).play(first);
      await app.until(() => home.player.state.playing as bool);
      await home.select(rows.last);
      expect(home.playbackMediaId, first['id']);
      expect(home.playingView, true);
      home.query = 'no-matching-file-for-rating-check';
      await home.refresh();
      await app.settle();
      expect(home.items, isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(PlaybackControls),
          matching: find.byTooltip('5점'),
        ),
      );
      await app.settle();
      expect(
        (await app.library.items()).firstWhere(
          (row) => row['id'] == first['id'],
        )['rating'],
        5,
      );
      expect(
        tester.widget<PlaybackControls>(find.byType(PlaybackControls)).rating,
        5,
      );
      home.query = '';
      await home.refresh();
      await app.settle();
      home.edit(mediaId: first['id'] as int);
      await app.settle(12);
      await tester.tap(
        find.descendant(
          of: find.byType(DetailEditor),
          matching: find.byTooltip('4점'),
        ),
      );
      await app.settle();
      expect(
        (await app.library.items()).firstWhere(
          (e) => e['id'] == first['id'],
        )['rating'],
        4,
      );
      await shot('details', find.byType(DetailEditor));
      await tester.tap(find.byTooltip('닫기'));
      await app.settle();
      final file = await File(
        '${app.root.path}/native-recycle-probe.txt',
      ).writeAsString('disposable integration fixture');
      await DesktopFiles.trash(file.path);
      expect(await file.exists(), false);
      final removeId = rows.last['id'] as int;
      final removal = home.fileAction(rows.last, 'trash') as Future<void>;
      await app.settle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('휴지통으로 이동'),
        ),
      );
      await removal;
      await app.settle();
      expect(
        await app.library.db.query(
          'media',
          where: 'id=?',
          whereArgs: [removeId],
        ),
        isEmpty,
      );
      expect(await app.library.readSetting('pending_trash'), isEmpty);

      await expectLater(DesktopFiles.trash(file.path), throwsA(anything));
      expect(tester.takeException(), isNull);
    } finally {
      await app.close();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
