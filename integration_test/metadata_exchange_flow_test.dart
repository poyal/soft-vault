import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soft_vault/metadata_exchange.dart';
import 'package:soft_vault/metadata_exchange_dialog.dart';
import 'support/scenario_app.dart';
import 'support/native_surface.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'whole metadata clipboard, files, cancel, restart request and apply',
    (tester) async {
      final app = await ScenarioApp.create(tester);
      final previousClipboard = await Clipboard.getData(Clipboard.kTextPlain);
      try {
        await app.mount();
        await resizeNativeSurface(tester, const Size(1000, 700));
        final exchange = MetadataExchange(app.library);
        Future<void> open() async {
          await tester.tap(find.byTooltip('영상정보 내보내기·입력하기'));
          await app.settle(10);
        }

        await open();
        await app.tap('AI 요청문 + 전체 정보 복사');
        final copied = (await Clipboard.getData(Clipboard.kTextPlain))!.text!;
        expect(copied, contains('requestId'));
        expect(copied, isNot(contains(app.source.path)));
        final request = (await exchange.load())!;
        expect((request['rows'] as List).length, 2);
        app.picker.savePath = '${app.root.path}/export.json';
        await app.tap('전체 정보 JSON 저장');
        expect(await File(app.picker.savePath!).exists(), isTrue);
        final result = jsonDecode(
          await File(app.picker.savePath!).readAsString(),
        );
        result['videos'][0]['title'] = 'AI 검증 제목';
        result['videos'][0]['actors'] = ['확인 배우'];
        final id = (request['rows'][0]['id']) as int;
        final before = (await app.library.db.query(
          'media',
          where: 'id=?',
          whereArgs: [id],
        )).single;
        await tester.tap(find.byTooltip('닫기'));
        await app.settle();
        await open();
        expect((await exchange.load())!['requestId'], request['requestId']);
        await app.tap('입력하기');
        app.picker.openPath = '${app.root.path}/response.json';
        await File(app.picker.openPath!).writeAsString(jsonEncode(result));
        await app.tap('JSON 파일 열기');
        await app.tap('변경 비교');
        expect(find.byType(CheckboxListTile), findsNWidgets(2));
        await tester.tap(find.byTooltip('닫기'));
        await app.settle();
        expect(
          (await app.library.db.query(
            'media',
            where: 'id=?',
            whereArgs: [id],
          )).single['title'],
          before['title'],
        );
        await open();
        await app.tap('입력하기');
        await Clipboard.setData(ClipboardData(text: jsonEncode(result)));
        await app.tap('결과 붙여넣기');
        await app.tap('변경 비교');
        await app.tap('선택한 변경 일괄 적용');
        await app.settle(15);
        expect(find.byType(MetadataExchangeDialog), findsNothing);
        expect(
          (await app.library.db.query(
            'media',
            where: 'id=?',
            whereArgs: [id],
          )).single['title'],
          'AI 검증 제목',
        );
        expect(
          (await app.library.entities(
            'actors',
          )).any((r) => r['name'] == '확인 배우'),
          isTrue,
        );
        expect(await exchange.load(), isNull);
      } finally {
        await Clipboard.setData(
          ClipboardData(text: previousClipboard?.text ?? ''),
        );
        await app.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
