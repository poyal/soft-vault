import 'support/native_surface.dart';
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
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/main.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real catalog to video selection, editing and persistent search',
    (tester) async {
      MediaKit.ensureInitialized();
      await windowManager.ensureInitialized();
      await prepareNativeSurface(tester);
      final root = await Directory(
        await Directory.systemTemp.resolveSymbolicLinks(),
      ).createTemp('soft-vault-e2e-');
      final media = await Directory(p.join(root.path, 'media')).create();
      const fixture = String.fromEnvironment('VIDEO_FIXTURE');
      await File(fixture).copy(p.join(media.path, 'sample.mp4'));
      final library = await Library.open(p.join(root.path, 'catalog.sqlite'));
      try {
        await library.connect(media.path);
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: VaultApp(library: library),
          ),
        );
        await tester.pumpAndSettle();
        final home = tester.state(find.byType(VaultHome)) as dynamic;
        final currentId = home.current?['id'];
        final check = find.byTooltip('sample 선택');
        await tester.tap(check);
        await tester.pump();
        expect(
          tester.widget<VaultFileList>(find.byType(VaultFileList)).selected,
          hasLength(1),
        );
        await tester.tap(check);
        await tester.pump();
        expect(
          tester.widget<VaultFileList>(find.byType(VaultFileList)).selected,
          isEmpty,
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(home.current?['id'], currentId);
        expect(home.player.state.playing, isFalse);
        await tester.tap(find.text('sample').last);
        await tester.pumpAndSettle();
        for (final size in [const Size(1440, 900), const Size(1280, 800)]) {
          await resizeNativeSurface(tester, size);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final boundary =
              captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final artifacts = await Directory(
            'build/e2e',
          ).create(recursive: true);
          await File(
            p.join(artifacts.path, 'library-${size.width.toInt()}.png'),
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        }
        await tester.tap(find.byTooltip('상세정보 보기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('정보 편집'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '수정한 제목');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await waitNativeMinimized(tester);
        expect(await windowManager.isMinimized(), isTrue);
        await restoreNativeWindow(tester);
        await tester.pumpAndSettle();
        expect(find.text('수정한 제목'), findsOneWidget);
        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();
        expect((await library.items(query: '수정한 제목')).length, 1);
        await tester.tap(find.byTooltip('5점'));
        await tester.pumpAndSettle();
        expect((await library.items()).single['rating'], 5);
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
