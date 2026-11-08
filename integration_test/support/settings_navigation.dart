import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openSettings(
  WidgetTester tester, [
  String section = '라이브러리',
]) async {
  await tester.tap(find.byTooltip('설정'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('settings-section-$section')));
  await tester.pumpAndSettle();
}

Future<void> settingsAction(WidgetTester tester, String label) async {
  const playback = {
    '이어보기',
    '처음부터 재생',
    '장면 북마크 · 메모',
    '음성 · 자막 · 디코더',
    '대표 썸네일 선택',
    'NFO 가져오기',
    'NFO 내보내기',
  };
  await openSettings(tester, playback.contains(label) ? '재생' : '라이브러리');
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.takeException(), isNull);
}
