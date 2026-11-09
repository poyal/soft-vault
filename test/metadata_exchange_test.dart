import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/metadata_exchange.dart';
import 'package:soft_vault/metadata_exchange_dialog.dart';

void main() {
  late Directory root;
  late Library library;
  late MetadataExchange service;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('metadata-exchange-');
    library = await Library.open('${root.path}/db.sqlite');
    for (var i = 1; i <= 2; i++) {
      await library.db.insert('media', {
        'id': i,
        'path': '${root.path}/$i/same.mp4',
        'folder': root.path,
        'title': '영상 $i',
        'type': 'video',
        'added': 1,
        'note': '개인 비밀',
        'rating': 5,
      });
    }
    service = MetadataExchange(library);
  });
  tearDown(() async {
    await library.close();
    await root.delete(recursive: true);
  });
  test(
    'whole export excludes private fields, survives restart and selectively applies',
    () async {
      final request = await service.create();
      final text = service.encode(request);
      expect(text, isNot(contains(root.path)));
      expect(text, isNot(contains('개인 비밀')));
      await library.close();
      library = await Library.open('${root.path}/db.sqlite');
      service = MetadataExchange(library);
      expect((await service.load())!['requestId'], request['requestId']);
      final result = jsonDecode(text);
      result['videos'][0]['title'] = '새 제목 & 한글';
      result['videos'][0]['actors'] = ['배우 A', '배우 B'];
      result['videos'][0]['description'] = '';
      final proposal = service.parse(
        '```json\n${jsonEncode(result)}\n```',
        request,
      );
      await service.apply(proposal, {
        1: {'actors'},
      });
      final row = (await library.db.query('media', where: 'id=1')).single;
      expect(row['title'], '영상 1');
      expect(row['actors'], '배우 A, 배우 B');
      expect(row['rating'], 5);
      expect(row['note'], '개인 비밀');
      expect((await library.entities('actors')).length, 2);
      expect(await service.load(), isNull);
      expect(
        root
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('before-ai-metadata'))
            .length,
        1,
      );
    },
  );
  test(
    'invalid, missing, duplicate and stale requests are handled without writes',
    () async {
      final request = await service.create();
      final result = jsonDecode(service.encode(request));
      result['videos'].removeLast();
      result['videos'][0]['title'] = '수정';
      final proposal = service.parse(jsonEncode(result), request);
      expect(proposal.missing, 1);
      result['videos'].add(result['videos'][0]);
      expect(
        () => service.parse(jsonEncode(result), request),
        throwsFormatException,
      );
      result['videos'].removeLast();
      result['videos'][0]['id'] = 'unknown';
      expect(
        () => service.parse(jsonEncode(result), request),
        throwsFormatException,
      );
      await service.create();
      await expectLater(
        service.apply(proposal, {
          1: {'title'},
        }),
        throwsStateError,
      );
      expect(
        (await library.db.query('media', where: 'id=1')).single['title'],
        '영상 1',
      );
    },
  );
  test('conflicts and SQL failures roll back every selected change', () async {
    final request = await service.create();
    final result = jsonDecode(service.encode(request));
    for (final row in result['videos']) {
      row['title'] = '새 제목';
    }
    final proposal = service.parse(jsonEncode(result), request);
    await library.edit(2, {'description': '외부 변경'});
    await expectLater(
      service.apply(proposal, {
        1: {'title'},
        2: {'title'},
      }),
      throwsStateError,
    );
    expect(
      (await library.db.query('media', where: 'id=1')).single['title'],
      '영상 1',
    );
    await library.edit(2, {'description': ''});
    await library.db.execute(
      "CREATE TRIGGER fail_title BEFORE UPDATE ON media WHEN NEW.id=2 BEGIN SELECT RAISE(ABORT,'failure'); END",
    );
    await expectLater(
      service.apply(proposal, {
        1: {'title'},
        2: {'title'},
      }),
      throwsA(anything),
    );
    expect(
      (await library.db.query('media', where: 'id=1')).single['title'],
      '영상 1',
    );
    expect(await service.load(), isNotNull);
  });
  test(
    'backup failure keeps all data and request; malformed fields never apply',
    () async {
      final request = await service.create();
      final result = jsonDecode(service.encode(request));
      result['videos'][0]['title'] = '변경';
      final proposal = service.parse(jsonEncode(result), request);
      final failing = MetadataExchange(
        library,
        backupWriter: (_) async {
          throw const FileSystemException('disk full');
        },
      );
      await expectLater(
        failing.apply(proposal, {
          1: {'title'},
        }),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        (await library.db.query('media', where: 'id=1')).single['title'],
        '영상 1',
      );
      expect(await service.load(), isNotNull);
      for (final bad in [
        42,
        '배우',
        [3],
        ['배우, 다른 배우'],
      ]) {
        result['videos'][0]['actors'] = bad;
        expect(
          () => service.parse(jsonEncode(result), request),
          throwsFormatException,
        );
      }
      result['videos'][0]['actors'] = [];
      result['videos'][0]['note'] = '금지 필드';
      expect(
        () => service.parse(jsonEncode(result), request),
        throwsFormatException,
      );
      result['videos'][0].remove('note');
      result['requestId'] = 'foreign';
      expect(
        () => service.parse(jsonEncode(result), request),
        throwsFormatException,
      );
    },
  );
  test(
    'empty library and 2000-video request preserve exact identity',
    () async {
      await library.db.delete('media');
      final empty = await service.create();
      expect(jsonDecode(service.encode(empty))['videos'], isEmpty);
      await library.db.transaction((tx) async {
        final batch = tx.batch();
        for (var i = 1; i <= 2000; i++) {
          batch.insert('media', {
            'id': i,
            'path': '$i/same.mp4',
            'folder': 'library',
            'title': '영상 $i',
            'type': 'video',
            'added': 1,
          });
        }
        await batch.commit(noResult: true);
      });
      final request = await service.create();
      final result = jsonDecode(service.encode(request));
      for (final row in result['videos']) {
        row['tags'] = ['태그'];
      }
      final proposal = service.parse(jsonEncode(result), request);
      expect(proposal.changes.length, 2000);
      await service.apply(proposal, {
        1: {'tags'},
        2000: {'tags'},
      });
      expect(
        (await library.db.query(
          'media',
          where: "tags='태그'",
        )).map((r) => r['id']).toSet(),
        {1, 2000},
      );
    },
  );
  testWidgets(
    'minimum window supports guide, whole request and compare selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final request = (await tester.runAsync(service.create))!;
      final result = jsonDecode(service.encode(request));
      result['videos'][0]['title'] = '새 이름';
      await tester.pumpWidget(
        MaterialApp(home: MetadataExchangeDialog(library: library)),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('사용 가이드와 복사용 요청문 보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('입력하기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), jsonEncode(result));
      await tester.tap(find.text('변경 비교'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('모두 해제'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '선택한 변경 일괄 적용'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
