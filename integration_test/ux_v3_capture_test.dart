import 'support/native_surface.dart';
import 'support/settings_navigation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import '../lib/main.dart';
import '../lib/library.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('matched to-be UI screenshots', (tester) async {
    MediaKit.ensureInitialized();
    await windowManager.ensureInitialized();
    await prepareNativeSurface(tester);
    await windowManager.setTitle('Soft Vault · to-be comparison capture');
    const repo = String.fromEnvironment('REPO_ROOT');
    const fixture = String.fromEnvironment('VIDEO_FIXTURE');
    final root = await Directory(
      p.join(repo, 'build/ux-v3-comparison/runtime-to-be'),
    ).create(recursive: true);
    final source = await Directory(
      p.join(await root.resolveSymbolicLinks(), '작업 폴더'),
    ).create(recursive: true);
    final target = await Directory(
      p.join(await root.resolveSymbolicLinks(), '외장 SSD'),
    ).create(recursive: true);
    final dbPath = p.join(
      root.path,
      'capture-' + DateTime.now().microsecondsSinceEpoch.toString() + '.sqlite',
    );
    final library = await Library.open(dbPath);
    final capture = GlobalKey();
    final previousClipboard = await Clipboard.getData(Clipboard.kTextPlain);
    Future<void> settle() async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> shot(String name) async {
      await settle();
      expectNativeSurface(tester);
      final image =
          await (capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = Directory(
        p.join(repo, 'artifacts/ux-v3-comparison/assets/to-be'),
      );
      await out.create(recursive: true);
      await File(
        p.join(out.path, name + '.png'),
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      debugPrint('CAPTURED to-be ' + name);
    }

    try {
      final rows =
          jsonDecode(
                await File(
                  p.join(repo, 'test/fixtures/design-media.json'),
                ).readAsString(),
              )
              as List;
      for (final row in rows) {
        await File(fixture).copy(
          p.join(
            row['folder'] == 'films' ? source.path : target.path,
            '${p.basenameWithoutExtension(row['file'] as String)}.mp4',
          ),
        );
      }
      await library.connect(source.path);
      await library.connect(target.path);
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i] as Map<String, dynamic>;
        final path = p.join(
          row['folder'] == 'films' ? source.path : target.path,
          '${p.basenameWithoutExtension(row['file'] as String)}.mp4',
        );
        final item = (await library.db.query(
          'media',
          where: 'path=?',
          whereArgs: [path],
        )).single;
        await library.edit(item['id'] as int, {
          'title': row['title'],
          'rating': row['rating'],
          'actors': (row['actors'] as List).join(', '),
          'tags': (row['tags'] as List).join(', '),
          'description': row['note'],
        });
        await library.db.update(
          'media',
          {
            'added': 100 - i,
            'duration': row['duration'],
            'codec': row['codec'],
            'resolution': row['resolution'],
            'thumbnail': p.join(repo, 'design/assets/${row['image']}.jpg'),
          },
          where: 'id=?',
          whereArgs: [item['id']],
        );
      }
      for (final entry in {
        '이서윤': 'Seoyun Lee',
        '김도현': 'Dohyun Kim',
        '박지우': 'Jiwoo Park',
      }.entries) {
        await library.db.update(
          'actors',
          {'alias': entry.value},
          where: 'name=?',
          whereArgs: [entry.key],
        );
      }

      await resizeNativeSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: VaultApp(library: library),
        ),
      );
      await settle();
      await shot('01-library');
      await settingsAction(tester, '썸네일 · 목록 보기');
      await shot('02-grid');
      await settingsAction(tester, '썸네일 · 목록 보기');
      await tester.tap(find.byTooltip('상세정보 보기'));
      await shot('03-detail');
      await tester.tap(find.text('닫기'));
      await settle();
      await tester.tap(find.text('배우').last);
      await shot('04-actors');
      await tester.tap(find.byTooltip('정보 편집').first);
      await shot('05-actor-editor');
      await tester.tap(find.text('취소'));
      await settle();
      await tester.tap(find.text('태그').last);
      await shot('06-tags');
      await tester.tap(find.byTooltip('필터'));
      await shot('07-filter');
      await tester.tap(find.text('취소'));
      await settle();
      await openSettings(tester);
      final settingsScroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('settings-body-라이브러리')),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(settingsScroll).position.jumpTo(0);
      await shot('08-settings');
      await openSettings(tester, '단축키');
      await shot('09-shortcuts');
      await openSettings(tester, '재생');
      await shot('10-playback-settings');
      await openSettings(tester, '메타데이터');
      await shot('11-metadata-location');
      await settle();
      await shot('12-metadata-export');
      await tester.tap(find.text('AI 요청문 + 전체 정보 복사'));
      await settle();
      await tester.tap(find.text('결과 입력으로 이동'));
      await shot('13-metadata-input');
      await tester.tap(find.text('배우 이미지'));
      await settle();
      await tester.ensureVisible(find.text('배우 검색'));
      await settle();
      await shot('14-actor-images');
      await tester.ensureVisible(find.text('김도현'));
      await tester.tap(find.text('김도현'));
      await shot('15-image-editor');
      await tester.tap(find.text('취소'));
      await settle();
    } finally {
      await Clipboard.setData(
        ClipboardData(text: previousClipboard?.text ?? ''),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await library.close();
    }
  });
}
