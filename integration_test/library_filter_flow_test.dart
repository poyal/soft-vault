import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/library_filter_dialog.dart';
import 'support/scenario_app.dart';
import 'support/native_surface.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('native library filter combinations, cancel and chips', (
    tester,
  ) async {
    final app = await ScenarioApp.create(tester, fixtures: 4);
    final capture = GlobalKey();
    try {
      final rows = await app.library.items();
      await app.library.edit(rows[0]['id'] as int, {
        'rating': 4,
        'actors': '이서윤, 김도현',
        'tags': '여행, 자연',
      });
      await app.library.edit(rows[1]['id'] as int, {
        'rating': 5,
        'actors': '이서윤',
        'tags': '여행',
      });
      final actor = (await app.library.entities(
        'actors',
      )).firstWhere((r) => r['name'] == '이서윤')['id'];
      final tag = (await app.library.entities(
        'tags',
      )).firstWhere((r) => r['name'] == '자연')['id'];
      await resizeNativeSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: VaultApp(library: app.library),
        ),
      );
      await app.settle(15);
      await tester.tap(find.byTooltip('필터'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-star-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('정확히'));
      await tester.pumpAndSettle();
      for (final key in ['배우-$actor', '태그-$tag']) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }
      await Directory('build/filter-review').create(recursive: true);
      // Capture the dialog repaint boundary rather than the root route behind it.
      final boundary = find
          .ancestor(
            of: find.byType(LibraryFilterDialog),
            matching: find.byType(RepaintBoundary),
          )
          .first;
      final image = await tester
          .renderObject<RenderRepaintBoundary>(boundary)
          .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/filter-review/filter.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      await tester.tap(find.text('적용'));
      await app.settle(8);
      expect(app.visible.map((r) => r['id']), [rows[0]['id']]);
      for (final size in [const Size(1000, 700), const Size(1440, 900)]) {
        await resizeNativeSurface(tester, size);
        await tester.tap(find.byTooltip('필터'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('필터 초기화'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('취소'));
        await app.settle();
        expect(app.visible.map((r) => r['id']), [rows[0]['id']]);
      }
      await tester.tap(find.text('필터 해제'));
      await app.settle(8);
      expect(app.visible.length, 4);
    } finally {
      await app.close();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
