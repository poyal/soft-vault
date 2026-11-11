import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openSettings(
  WidgetTester tester, [
  String section = '라이브러리',
]) async {
  if (find.byKey(ValueKey('settings-section-$section')).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(ValueKey('settings-section-$section')));
  await tester.pumpAndSettle();
}

Future<void> settingsAction(WidgetTester tester, String label) async {
  if (label == '다시 검색') {
    if (find.text('영상으로 돌아가기').evaluate().isNotEmpty) {
      await tester.tap(find.text('영상으로 돌아가기'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('전체 폴더 새로고침'));
    await tester.pumpAndSettle();
    return;
  }
  const playback = {
    '이어보기',
    '처음부터 재생',
    '장면 북마크 · 메모',
    '음성 · 자막 · 디코더',
    '대표 썸네일 선택',
    'NFO 가져오기',
    'NFO 내보내기',
  };
  await openSettings(
    tester,
    label.startsWith('NFO') || label == '영상정보 내보내기·입력하기'
        ? '메타데이터'
        : playback.contains(label)
        ? '재생'
        : '라이브러리',
  );
  if (label == '영상정보 내보내기·입력하기') return;
  if (label.startsWith('NFO')) {
    await tester.tap(find.text('NFO 관리'));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.takeException(), isNull);
}
