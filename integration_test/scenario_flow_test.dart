import 'support/file_navigation.dart';
import 'support/native_surface.dart';
import 'support/settings_navigation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/advanced_catalog.dart';
import 'package:soft_vault/player_controls.dart';
import 'package:soft_vault/file_list.dart';
import 'support/scenario_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final results = <Map<String, Object?>>[];
  void scenario(
    String name,
    Future<void> Function(ScenarioApp) action, {
    int videos = 0,
    int fixtures = 2,
  }) {
    testWidgets(name, (tester) async {
      final watch = Stopwatch()..start();
      final result = <String, Object?>{'name': name, 'passed': false};
      ScenarioApp? app;
      try {
        app = await ScenarioApp.create(
          tester,
          fixtures: fixtures,
          videos: videos,
        );
        await action(app);
        result['passed'] = true;
      } catch (e) {
        result['error'] = '$e';
        rethrow;
      } finally {
        await app?.close();
        result['ms'] = watch.elapsedMilliseconds;
        results.add(result);
        await Directory('build/e2e').create(recursive: true);
        await File(
          'build/e2e/scenario-results.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  scenario(
    'UI-18 unified settings navigation, resizing and shortcut presets persist',
    (app) async {
      await app.mount();
      final tester = app.tester;
      expect(find.byTooltip('파일·정리 메뉴'), findsNothing);
      expect(find.byTooltip('설정 · 단축키'), findsNothing);
      expect(find.text('2개 파일'), findsNothing);
      expect(
        tester.getCenter(find.byTooltip('설정')).dx,
        greaterThan(tester.getCenter(find.text('soft vault.')).dx),
      );
      expect(
        tester.getCenter(find.byTooltip('설정')).dy,
        closeTo(tester.getCenter(find.text('soft vault.')).dy, 1),
      );
      expect(
        tester.getBottomRight(find.byType(VaultFileList)).dy,
        tester.getBottomRight(find.byKey(const ValueKey('library-sidebar'))).dy,
      );
      await openSettings(tester);
      for (final size in [const Size(1000, 700), const Size(1440, 900)]) {
        await resizeNativeSurface(tester, size);
        for (final name in ['라이브러리', '재생', '백업', '단축키']) {
          await tester.tap(find.byKey(ValueKey('settings-section-$name')));
          await app.settle();
          expect(tester.takeException(), isNull);
        }
      }
      await app.tap('Space');
      await app.key(LogicalKeyboardKey.f8);
      await app.tap('표준 + 왼손 보조');
      await tester.enterText(find.byType(TextField).first, '새 설정 프리셋');
      await app.tap('프리셋 저장');
      await app.tap('닫기');
      await app.tap('기본값');
      expect(find.text('Space'), findsOneWidget);
      await app.tap('표준 + 왼손 보조');
      await app.tap('새 설정 프리셋');
      expect(find.text('F8'), findsOneWidget);
      await app.tap('영상으로 돌아가기');
      await openSettings(tester, '단축키');
      expect(find.text('F8'), findsOneWidget);
      await openSettings(tester);
      await app.tap('연결 폴더 관리');
      await app.tap('닫기');
      await app.tap('영상으로 돌아가기');
      expect(app.visible.length, 2);
    },
  );
  scenario(
    'UI-19 empty library settings disable video actions and keep folder entry available',
    (app) async {
      await app.mount();
      await openSettings(app.tester, '재생');
      for (final label in ['이어보기', '처음부터 재생']) {
        expect(
          app.tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, label),
              )
              .onPressed,
          isNull,
        );
      }
      await openSettings(app.tester, '메타데이터');
      await app.tap('NFO 관리');
      for (final label in ['NFO 가져오기', 'NFO 내보내기']) {
        expect(
          app.tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, label),
              )
              .onPressed,
          isNull,
        );
      }
      await openSettings(app.tester);
      expect(
        app.tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '폴더 연결'))
            .onPressed,
        isNotNull,
      );
      expect(find.byType(VaultFileList), findsNothing);
      await app.tap('영상으로 돌아가기');
      expect(app.visible, isEmpty);
    },
    fixtures: 0,
  );
  scenario(
    'UI-17 list and grid show actors and tags without overflow or changing selection',
    (app) async {
      final a = await app.row('fixture-0'), b = await app.row('fixture-1');
      final id = a['id'] as int;
      await app.library.edit(id, {
        'actors': '배우 A, 아주 긴 배우 이름 B, 배우 C',
        'tags': '자연, 긴 태그 이름, 여행, 기록',
      });
      await app.mount();
      for (final grid in [false, true]) {
        if (grid) await app.menu('썸네일 · 목록 보기');
        for (final size in [
          const Size(1000, 700),
          const Size(1280, 800),
          const Size(1440, 900),
        ]) {
          await resizeNativeSurface(app.tester, size);
          await app.settle(2);
          final actor = find.byKey(ValueKey('file-actors-$id'));
          final tag = find.byKey(ValueKey('file-tags-$id'));
          expect(
            app.tester.widget<Text>(actor).data,
            '배우 A · 아주 긴 배우 이름 B · 배우 C',
          );
          expect(
            app.tester.widget<Text>(tag).data,
            '#자연 · #긴 태그 이름 · #여행 · #기록',
          );
          expect(
            find.byTooltip('배우: 배우 A · 아주 긴 배우 이름 B · 배우 C'),
            findsOneWidget,
          );
          expect(
            app.tester
                .widget<Text>(find.byKey(ValueKey('file-actors-${b['id']}')))
                .data,
            '배우 미등록',
          );
          expect(
            app.tester
                .widget<Text>(find.byKey(ValueKey('file-tags-${b['id']}')))
                .data,
            '지정된 태그 없음',
          );
          await app.tester.ensureVisible(actor);
          await app.settle();
          await app.tester.tap(actor);
          await app.settle();
          expect(
            app.tester
                .widget<VaultFileList>(find.byType(VaultFileList))
                .current,
            id,
          );
          expect(app.tester.takeException(), isNull);
        }
      }
    },
  );
  scenario('UI-13 images never enter the video library', (app) async {
    await File(p.join(app.source.path, 'poster.jpg')).writeAsBytes([1, 2, 3]);
    await app.library.scan(app.source.path);
    await app.mount();
    expect(app.visible.length, 2);
    expect(app.visible.every((row) => row['type'] == 'video'), isTrue);
    expect(find.text('이미지'), findsNothing);
    expect(await File(p.join(app.source.path, 'poster.jpg')).exists(), isTrue);
  });
  scenario(
    'UI-14 clicking the video toggles pause without changing volume or fullscreen',
    (app) async {
      await app.mount();
      await app.key(LogicalKeyboardKey.space);
      final player = app.player;
      await app.until(() => player.state.playing);
      await app.key(LogicalKeyboardKey.keyW);
      final volume = player.state.volume;
      expect(find.text('소리 꺼짐'), findsNothing);
      expect(find.byTooltip('라이브러리로 돌아가기'), findsNothing);
      expect(
        app.tester.getTopLeft(find.byKey(const ValueKey('video-surface'))).dy,
        0,
      );
      for (var i = 0; i < 4; i++) {
        await app.tester.tap(find.byKey(const ValueKey('video-surface')));
        await app.until(() => player.state.playing == i.isOdd);
        expect(player.state.volume, volume);
      }
      await app.key(LogicalKeyboardKey.keyF);
      await app.tester.tap(find.byKey(const ValueKey('video-surface')));
      await app.until(() => !player.state.playing);
      await app.tester.tap(find.byKey(const ValueKey('video-surface')));
      await app.until(() => player.state.playing);
      expect(player.state.volume, volume);
    },
    fixtures: 0,
    videos: 1,
  );
  scenario(
    'UI-15 detail opens read-only and editing remains explicit and persistent',
    (app) async {
      await app.mount();
      await openFileDetails(app.tester);
      await app.settle();
      expect(find.text('상세정보'), findsWidgets);
      expect(find.byType(TextField), findsNothing);
      await app.tap('정보 편집');
      await app.tester.enterText(find.byType(TextField).first, '영상 정보 수정');
      await app.tap('저장');
      expect((await app.library.items(query: '영상 정보 수정')).length, 1);
    },
  );
  scenario(
    'UI-16 actors and tags expose All and clear smart collection filters',
    (app) async {
      final a = await app.row('fixture-0');
      await app.library.edit(a['id'] as int, {'actors': '출연자', 'tags': '선택'});
      await app.library.saveCollection('한 편만', const MediaCriteria(tags: '선택'));
      await app.mount();
      for (final entry in {'배우': 'actors', '태그': 'tags'}.entries) {
        await app.menu('스마트 컬렉션 · 중복 · 이동 규칙');
        await app.tap('한 편만');
        expect(app.visible.length, 1);
        await app.tap(entry.key);
        await app.tester.tap(find.byKey(ValueKey('${entry.value}-all')));
        await app.settle();
        expect(app.visible.length, 2);
      }
    },
  );
  scenario('UI-01 actor navigation clears an active smart collection', (
    app,
  ) async {
    final a = await app.row('fixture-0'), b = await app.row('fixture-1');
    await app.library.edit(a['id'] as int, {'actors': '첫 배우', 'tags': '첫째'});
    await app.library.edit(b['id'] as int, {'actors': '둘째 배우', 'tags': '둘째'});
    await app.library.saveCollection('첫 컬렉션', const MediaCriteria(tags: '첫째'));
    await app.mount();
    await app.menu('스마트 컬렉션 · 중복 · 이동 규칙');
    await app.tap('첫 컬렉션');
    expect(app.visible.length, 1);
    await app.tap('배우');
    await app.tap('둘째 배우');
    expect(app.visible.single['id'], b['id']);
  });
  scenario(
    'UI-02 offline event stops playback even when online-only collection hides the row',
    (app) async {
      await app.library.saveCollection(
        '온라인',
        const MediaCriteria(onlineOnly: true),
      );
      await app.mount();
      await app.menu('스마트 컬렉션 · 중복 · 이동 규칙');
      await app.tap('온라인');
      await app.key(LogicalKeyboardKey.space);
      final player = app.player;
      await app.until(() => player.state.position > Duration.zero);
      await app.library.disconnect(app.source.path);
      await app.menu('다시 검색');
      await app.settle(10);
      expect(app.visible, isEmpty);
      expect(player.state.playing, isFalse);
      expect(find.byType(PlaybackControls), findsNothing);
    },
    fixtures: 0,
    videos: 1,
  );
  scenario(
    'UI-03 corrupted media displays an error and valid playback recovers',
    (app) async {
      await File(
        p.join(app.source.path, 'broken.mp4'),
      ).writeAsString('invalid video');
      await app.library.scan(app.source.path);
      await app.mount();
      await app.tap('broken');
      await app.key(LogicalKeyboardKey.space);
      await app.until(() => find.byType(MaterialBanner).evaluate().isNotEmpty);
      await app.tap('닫기');
      final validVideo = find.text('video-0').last;
      await app.tester.ensureVisible(validVideo);
      await playFileCard(app.tester, validVideo);
      await app.settle();
      final player = app.player;
      await app.until(
        () =>
            player.state.position > Duration.zero &&
            (player.state.videoParams.dw ?? 0) > 0,
      );
      expect(player.state.volume, 0);
    },
    fixtures: 0,
    videos: 1,
  );
  scenario(
    'UI-04 cancelling NFO chooser and import preview leaves metadata untouched',
    (app) async {
      await app.mount();
      await app.menu('NFO 가져오기');
      expect(app.picker.opened, 1);
      final before = app.visible.first;
      final nfo = await File(
        p.join(app.root.path, 'import.nfo'),
      ).writeAsString('<movie><title>교체 제목</title></movie>');
      app.picker.openPath = nfo.path;
      await app.menu('NFO 가져오기');
      await app.tap('취소');
      expect(
        (await app.library.mediaById(before['id'] as int))['title'],
        before['title'],
      );
    },
  );
  scenario(
    'UI-05 NFO import confirms, writes backup and preserves multiline Unicode',
    (app) async {
      await app.mount();
      final id = app.visible.first['id'] as int;
      final nfo = await File(p.join(app.root.path, 'import.nfo')).writeAsString(
        '<movie><title>한글 &amp; 새 제목</title><plot>첫 줄\n둘째 줄</plot><tag>가져옴</tag></movie>',
      );
      app.picker.openPath = nfo.path;
      await app.menu('NFO 가져오기');
      await app.tap('가져오기');
      expect((await app.library.mediaById(id))['title'], '한글 & 새 제목');
      expect((await app.library.mediaById(id))['description'], '첫 줄\n둘째 줄');
      expect(
        (await app.root
                .list()
                .where((f) => p.basename(f.path).startsWith('before-nfo-'))
                .toList())
            .length,
        1,
      );
    },
  );
  scenario(
    'UI-06 NFO overwrite cancellation and replacement preserve original backup',
    (app) async {
      await app.mount();
      final nfo = await File(
        p.join(app.root.path, 'export.nfo'),
      ).writeAsString('original');
      app.picker.savePath = nfo.path;
      await app.menu('NFO 내보내기');
      await app.tap('취소');
      expect(await nfo.readAsString(), 'original');
      await app.menu('NFO 내보내기');
      await app.tap('백업 후 교체');
      expect(await nfo.readAsString(), contains('<movie>'));
      final backups = await app.root
          .list()
          .where((f) => f.path.contains('.backup-'))
          .toList();
      expect(await (backups.single as File).readAsString(), 'original');
    },
  );
  scenario(
    'UI-07 malformed JSON restore reports error without deleting catalog',
    (app) async {
      await app.mount();
      final file = await File(
        p.join(app.root.path, 'bad.json'),
      ).writeAsString('{"version":3,"media":[]}');
      app.picker.openPath = file.path;
      await openSettings(app.tester, '백업');
      await app.settle();

      await app.tap('백업 복원');
      await app.tap('복원');
      await app.until(() => find.byType(MaterialBanner).evaluate().isNotEmpty);
      expect((await app.library.items()).length, 2);
    },
  );
  scenario(
    'UI-08 bookmark edit cancellation, update and delete persist correctly',
    (app) async {
      final id = (await app.row('video-0'))['id'] as int;
      await app.library.saveBookmark(
        id,
        const Duration(seconds: 3),
        title: '원래 장면',
        note: '원래 메모',
      );
      await app.mount();
      await app.menu('장면 북마크 · 메모');
      await app.tester.tap(find.byTooltip('장면 편집'));
      await app.settle();
      await app.tester.enterText(find.byType(TextField).first, '취소될 제목');
      await app.tap('취소');
      expect((await app.library.bookmarks(id)).single['title'], '원래 장면');
      await app.tester.tap(find.byTooltip('장면 편집'));
      await app.settle();
      await app.tester.enterText(find.byType(TextField).first, '수정 장면');
      await app.tap('저장');
      expect((await app.library.bookmarks(id)).single['title'], '수정 장면');
      await app.tester.tap(find.byTooltip('장면 삭제'));
      await app.settle();
      expect(await app.library.bookmarks(id), isEmpty);
    },
    fixtures: 0,
    videos: 1,
  );
  scenario(
    'UI-09 collection delete cancellation preserves condition, confirmation removes only condition',
    (app) async {
      await app.library.saveCollection('삭제할 조건', const MediaCriteria());
      await app.mount();
      await app.menu('스마트 컬렉션 · 중복 · 이동 규칙');
      await app.tester.tap(find.byTooltip('조건 삭제'));
      await app.settle();
      await app.tap('취소');
      expect((await app.library.collections()).length, 1);
      await app.tester.tap(find.byTooltip('조건 삭제'));
      await app.settle();
      await app.tap('삭제');
      expect(await app.library.collections(), isEmpty);
      expect((await app.library.items()).length, 2);
    },
  );
  scenario(
    'UI-10 duplicate source change is reported by comparison without deleting either file',
    (app) async {
      await app.mount();
      await app.menu('스마트 컬렉션 · 중복 · 이동 규칙');
      await app.tap('중복 비교');
      await app.tap('동일 SHA-256');
      await File(p.join(app.source.path, 'fixture-0.mp4')).writeAsBytes([9, 8]);
      await app.tap('내용 재검증');
      expect(find.text('내용이 다르거나 오프라인입니다.'), findsOneWidget);
      expect(
        await File(p.join(app.source.path, 'fixture-1.mp4')).exists(),
        isTrue,
      );
    },
  );
  scenario(
    'UI-11 backup export and confirmed restore recover edited metadata',
    (app) async {
      await app.mount();
      final id = app.visible.first['id'] as int;
      final backup = File(p.join(app.root.path, 'restore.json'));
      app.picker.savePath = backup.path;
      await openSettings(app.tester, '백업');
      await app.settle();

      await app.tap('백업 · 내보내기');
      expect(await backup.exists(), isTrue);
      await app.library.edit(id, {'title': '복원할 변경'});
      app.picker.openPath = backup.path;
      await app.tap('백업 복원');
      await app.tap('복원');
      expect((await app.library.mediaById(id))['title'], isNot('복원할 변경'));
    },
  );
  scenario(
    'UI-12 connect chooser cancellation adds no root and valid choice scans files',
    (app) async {
      await app.mount();
      await app.tester.tap(find.byTooltip('폴더 연결'));
      await app.settle();
      expect((await app.library.folders()).length, 2);
      final extra = await Directory(p.join(app.root.path, '추가 폴더')).create();
      await File(
        p.join(app.source.path, 'fixture-0.mp4'),
      ).copy(p.join(extra.path, 'extra.mp4'));
      app.picker.directoryPath = extra.path;
      await app.tester.tap(find.byTooltip('폴더 연결'));
      await app.settle(15);
      expect((await app.library.folders()).length, 3);
      expect(app.visible.length, 3);
    },
  );
}
