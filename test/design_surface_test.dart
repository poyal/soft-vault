import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:soft_vault/design.dart';
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/welcome_dialog.dart';
import 'package:soft_vault/detail_dialog.dart';
import 'package:soft_vault/criteria_dialog.dart';
import 'package:soft_vault/library_filter.dart';
import 'package:soft_vault/library_filter_dialog.dart';
import 'package:soft_vault/player_controls.dart';

class _PreviewPlayer extends Fake implements Player {
  @override
  PlayerState get state => const PlayerState(
    position: Duration(seconds: 10),
    duration: Duration(seconds: 52),
    volume: 0,
  );
  @override
  PlayerStream get stream => _PreviewStream();
}

class _PreviewStream extends Fake implements PlayerStream {
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<double> get volume => const Stream.empty();
}

void main() {
  testWidgets('playback stars accept clicks across their full hit area', (
    tester,
  ) async {
    int? savedRating;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PlaybackControls(
              player: _PreviewPlayer(),
              muted: true,
              command: (_) {},
              volume: (_) {},
              subtitle: () {},
              decoder: () {},
              rating: savedRating,
              rate: (value) => setState(() => savedRating = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.byTooltip('4점');
    expect(tester.getSize(target), const Size(24, 36));
    await tester.tapAt(tester.getTopLeft(target) + const Offset(3, 3));
    await tester.pump();
    expect(savedRating, 4);
    expect(tester.widget<DeckStars>(find.byType(DeckStars)).rating, 4);
  });

  testWidgets('keyboard hints remain compact in wrapping playback controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: Wrap(
              spacing: 8,
              children: [KeyCap('Esc'), KeyCap('Q'), KeyCap('E')],
            ),
          ),
        ),
      ),
    );
    final caps = find.byType(KeyCap);
    for (var i = 0; i < 3; i++) {
      expect(tester.getSize(caps.at(i)).width, lessThan(70));
      expect(
        tester.getTopLeft(caps.at(i)).dy,
        tester.getTopLeft(caps.first).dy,
      );
    }
    expect(tester.takeException(), isNull);
  });

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
      for (final width in [440.0, 700.0])
        'controls-$width': Center(
          child: SizedBox(
            width: width,
            child: PlaybackControls(
              player: _PreviewPlayer(),
              muted: true,
              command: (_) {},
              volume: (_) {},
              subtitle: () {},
              decoder: () {},
              detail: () {},
              rating: 4,
              rate: (_) {},
            ),
          ),
        ),
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
              current: 1,
              grid: grid,
              preview: (_) {},
              play: (_) {},
              action: (_, _) {},
              playingId: 1,
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
