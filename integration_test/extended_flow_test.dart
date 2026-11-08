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
import 'package:soft_vault/advanced_catalog.dart';
import 'package:soft_vault/media_tools.dart';
import 'package:soft_vault/nfo_service.dart';
import 'package:soft_vault/player_controls.dart';
import 'package:soft_vault/thumbnail_dialog.dart';
import 'package:soft_vault/hover_preview.dart';
import 'package:soft_vault/file_list.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'resume, scenes, collections, duplicates, thumbnails, previews, rules and NFO',
    (tester) async {
      MediaKit.ensureInitialized();
      await windowManager.ensureInitialized();
      await prepareNativeSurface(tester);
      await windowManager.setTitle('Soft Vault · E2E - extended_flow_test');
      const fixture = String.fromEnvironment('VIDEO_FIXTURE');
      final root = await Directory(
        await Directory.systemTemp.resolveSymbolicLinks(),
      ).createTemp('vault-extended-e2e-');
      final source = await Directory(p.join(root.path, '원본')).create();
      final target = await Directory(p.join(root.path, '정리')).create();
      await File(fixture).copy(p.join(source.path, '여행.mp4'));
      await File(fixture).copy(p.join(source.path, '복사본.mp4'));
      final library = await Library.open(p.join(root.path, 'db.sqlite'));
      final tools = MediaTools(
        library,
        Directory(p.join(root.path, 'thumbnails')),
        MediaTools.bundledBin(),
      );
      final capture = GlobalKey();
      Future<void> settle([int count = 10]) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
      }

      Future<void> menu(String label) async {
        await settingsAction(tester, label);
        await settle();
      }

      Future<void> shot(String name) async {
        for (final size in [const Size(1440, 900), const Size(1280, 800)]) {
          await resizeNativeSurface(tester, size);
          await settle(3);
          expectNativeSurface(tester);
          final image =
              await (capture.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/e2e').create(recursive: true);
          await File(
            'build/e2e/$name-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        }
      }

      try {
        await library.connect(source.path);
        await library.connect(target.path);
        await tools.enrich();
        final id =
            (await library.items()).firstWhere(
                  (row) => row['title'] == '여행',
                )['id']
                as int;
        await library.edit(id, {'tags': '여행, 자연', 'description': '첫 줄\n둘째 줄'});
        await resizeNativeSurface(tester, const Size(1280, 800));
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: VaultApp(library: library),
          ),
        );
        await settle(20);
        await tester.tap(find.text('여행').last);
        await settle();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await settle(20);
        final player = tester
            .widget<PlaybackControls>(find.byType(PlaybackControls))
            .player;
        await player.pause();
        await player.seek(const Duration(seconds: 12));
        await settle();
        await tester.tap(find.text('여행').last);
        await settle();
        expect(
          (await library.mediaById(id))['resume_ms'],
          greaterThanOrEqualTo(11000),
        );
        await menu('이어보기');
        await settle(20);
        expect(player.state.position.inSeconds, greaterThanOrEqualTo(11));
        expect(player.state.volume, 0);
        await player.pause();
        await menu('장면 북마크 · 메모');
        await tester.tap(find.text('현재 장면 추가'));
        await settle();
        await tester.enterText(find.byType(TextField).at(0), '기억할 장면');
        await tester.enterText(find.byType(TextField).at(1), '8.5');
        await tester.enterText(find.byType(TextField).at(2), '한글 메모 & <장면>');
        await tester.tap(find.text('저장'));
        await settle();
        expect((await library.bookmarks(id)).single['position_ms'], 8500);
        await shot('14-scenes');
        await tester.tap(find.text('기억할 장면'));
        await settle();
        expect(player.state.position.inMilliseconds, closeTo(8500, 1000));
        await menu('대표 썸네일 선택');
        for (
          var i = 0;
          i < 300 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final frames = find.descendant(
          of: find.byType(ThumbnailDialog),
          matching: find.byType(Image),
        );
        expect(frames.evaluate().length, greaterThanOrEqualTo(5));
        await tester.tap(frames.at(2));
        await shot('15-thumbnails');
        await tester.tap(find.text('적용'));
        await settle();
        final chosen = (await library.mediaById(id))['thumbnail'];
        expect((await library.mediaById(id))['custom_thumbnail'], 1);
        await tools.enrich();
        expect((await library.mediaById(id))['thumbnail'], chosen);
        final preview = await tools.preview(await library.mediaById(id));
        final bytes = await File(preview).readAsBytes();
        expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
        expect(String.fromCharCodes(bytes), contains('ANIM'));
        expect(await tools.preview(await library.mediaById(id)), preview);
        await tester.tap(find.text('여행').last);
        await settle();
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(HoverPreview).first));
        for (
          var i = 0;
          i < 100 && find.byIcon(Icons.volume_off_outlined).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
        expect(player.state.volume, 0);
        await shot('19-hover-preview');
        await mouse.moveTo(Offset.zero);
        await mouse.removePointer();
        await settle();
        await menu('현재 조건을 컬렉션으로 저장');
        await tester.enterText(find.byType(TextField).first, '다시 볼 여행');
        await tester.enterText(find.byType(TextField).at(2), '여행');
        await tester.tap(find.text('저장'));
        await settle();
        expect((await library.collections()).single['name'], '다시 볼 여행');
        await menu('스마트 컬렉션 · 중복 · 이동 규칙');
        await shot('16-collections');
        await tester.tap(find.text('다시 볼 여행'));
        await settle();
        expect(
          tester.widget<VaultFileList>(find.byType(VaultFileList)).items.length,
          1,
        );
        await menu('스마트 컬렉션 · 중복 · 이동 규칙');
        await tester.tap(find.text('중복 비교'));
        await settle();
        await tester.tap(find.text('동일 SHA-256').first);
        await settle();
        await tester.tap(find.text('내용 재검증'));
        await settle(30);
        expect(find.text('현재 파일 내용이 동일합니다.'), findsOneWidget);
        await shot('17-duplicates');
        await tester.tap(find.text('닫기'));
        await settle();
        await tester.tap(find.text('이동 규칙'));
        await settle();
        await tester.tap(find.text('규칙 추가'));
        await settle();
        await tester.enterText(find.byType(TextField).first, '여행 분류');
        await tester.enterText(find.byType(TextField).at(2), '여행');
        final dropdowns = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(dropdowns.first);
        await tester.tap(dropdowns.first);
        await settle(3);
        await tester.tap(find.text('원본').last);
        await settle(3);
        await tester.ensureVisible(dropdowns.last);
        await tester.tap(dropdowns.last);
        await settle(3);
        await tester.tap(find.text('정리').last);
        await settle(3);
        await tester.tap(find.text('저장'));
        await settle();
        expect((await library.moveRules()).single['enabled'], 0);
        await tester.tap(find.text('여행 분류').first);
        await settle();
        await shot('18-rules');
        expect(await File(p.join(source.path, '여행.mp4')).exists(), isTrue);
        await tester.tap(find.text('이동 실행'));
        await settle(30);
        expect((await library.mediaById(id))['folder'], target.path);
        expect(await File(p.join(target.path, '여행.mp4')).exists(), isTrue);
        expect((await library.bookmarks(id)).single['note'], '한글 메모 & <장면>');
        expect((await library.mediaById(id))['thumbnail'], chosen);
        final nfo = NfoService(library),
            sidecar = File(p.join(target.path, '여행.nfo'));
        await nfo.write(id, sidecar);
        final data = await nfo.read(sidecar);
        expect(data.fields['description'], '첫 줄\n둘째 줄');
        await library.deleteBookmark(
          (await library.bookmarks(id)).single['id'] as int,
        );
        await nfo.apply(id, data);
        expect((await library.bookmarks(id)).length, 1);
        await library.exportTo(File(p.join(root.path, 'backup.json')));
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
