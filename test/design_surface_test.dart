import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/design.dart';
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/welcome_dialog.dart';
import 'package:soft_vault/detail_dialog.dart';
import 'package:soft_vault/criteria_dialog.dart';
import 'package:soft_vault/library_filter.dart';
import 'package:soft_vault/library_filter_dialog.dart';

void main() {
  testWidgets('main surfaces fit minimum window at supported text scales', (
    tester,
  ) async {
    if (Platform.isWindows)
      await tester.runAsync(() async {
        final loader = FontLoader('Segoe UI');
        loader.addFont(
          File(
            'C:/Windows/Fonts/malgun.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
        await loader.load();
      });
    final item = <String, Object?>{
      'id': 1,
      'title': '긴 한글 영상 제목 ' * 8,
      'path': 'C:/media/video.mp4',
      'folder': 'C:/media',
      'type': 'video',
      'online': 1,
      'duration': 120,
      'size': 1048576,
      'actors': '배우 이름',
      'tags': '태그',
      'description': '설명',
      'note': '메모',
      'modified': 1,
      'thumbnail': '',
      'rating': 4,
    };
    final surfaces = <String, Widget>{
      'welcome': const WelcomeDialog(),
      'detail': DetailEditor(
        item: item,
        play: () {},
        rename: () {},
        external: () {},
        relink: () {},
      ),
      'criteria': CriteriaDialog(folders: const [], save: (_) async {}),
      'filters': LibraryFilterDialog(
        initial: LibraryFilter(),
        actors: const [
          {'id': 1, 'name': '배우', 'alias': ''},
        ],
        tags: const [
          {'id': 1, 'name': '태그'},
        ],
      ),
      for (final grid in [true, false])
        'files-' + grid.toString(): Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 340,
            child: VaultFileList(
              items: [
                item,
                {...item, 'id': 2},
              ],
              selected: const {2},
              current: 1,
              grid: grid,
              toggle: (_) {},
              preview: (_) {},
              play: (_) {},
            ),
          ),
        ),
    };
    final capture = GlobalKey();
    try {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      for (final scale in [1.0, 1.25, 1.5]) {
        for (final entry in surfaces.entries) {
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey(entry.key + scale.toString()),
              theme: ThemeData(
                brightness: Brightness.dark,
                fontFamily: 'Segoe UI',
              ).copyWith(scaffoldBackgroundColor: DeckDesign.background),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: RepaintBoundary(key: capture, child: entry.value),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: entry.key + ' scale ' + scale.toString(),
          );
          if (scale == 1)
            await tester.runAsync(() async {
              final image =
                  await (capture.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/surface-review').create(recursive: true);
              await File(
                'build/surface-review/' + entry.key + '.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    }
  });
}
