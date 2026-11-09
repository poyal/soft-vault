import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/advanced_catalog.dart';
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/playback_history.dart';
import 'package:soft_vault/playback_history_dialog.dart';
import 'support/scenario_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('real playback counts sessions and filters played videos', (
    tester,
  ) async {
    final app = await ScenarioApp.create(tester);
    try {
      await app.mount();
      final row = (await app.library.items()).first;
      final id = row['id'] as int;
      final play = tester
          .widget<VaultFileList>(find.byType(VaultFileList))
          .play;
      final dynamic home = tester.state(find.byType(VaultHome));
      Future<void> count(int expected) async {
        for (var i = 0; i < 100; i++) {
          if ((await app.library.mediaById(id))['play_count'] == expected)
            return;
          await app.settle(1);
        }
        expect((await app.library.mediaById(id))['play_count'], expected);
      }

      play(row);
      await count(1);
      await home.player.pause();
      await home.player.seek(const Duration(seconds: 10));
      await home.player.play();
      await app.settle(20);
      await count(1);
      play(row);
      await count(2);
      await home.player.seek(
        home.player.state.duration - const Duration(milliseconds: 500),
      );
      await app.until(() => home.player.state.completed as bool);
      await home.player.play();
      await count(3);
      expect((await app.library.playbackHistory(id)).length, 3);
      await home.select(row);
      await app.settle();
      await tester.tap(find.byTooltip('필터'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-playback-unplayed')));
      await tester.tap(find.text('적용'));
      await app.settle(10);
      expect(app.visible.length, 1);
      expect(app.visible.single['id'], isNot(id));
      await tester.tap(find.byTooltip('필터'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-playback-played')));
      await tester.tap(find.text('적용'));
      await app.settle(10);
      expect(app.visible.single['id'], id);
      home.edit();
      await app.settle(10);
      expect(find.text('3회'), findsOneWidget);
      await tester.ensureVisible(find.text('재생 이력'));
      await tester.tap(find.text('재생 이력'));
      await app.settle(10);
      expect(
        find.descendant(
          of: find.byType(PlaybackHistoryDialog),
          matching: find.byType(ListTile),
        ),
        findsNWidgets(3),
      );
      final boundary = find
          .ancestor(
            of: find.byType(PlaybackHistoryDialog),
            matching: find.byType(RepaintBoundary),
          )
          .first;
      final image = await tester
          .renderObject<RenderRepaintBoundary>(boundary)
          .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/playback-review').create(recursive: true);
      await File(
        'build/playback-review/history.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    } finally {
      await app.close();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
