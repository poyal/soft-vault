import 'package:flutter_test/flutter_test.dart';

/// Open details through the visible action for the current playback state.
Future<void> openFileDetails(WidgetTester tester) async {
  final selected = find.text('선택 파일 상세정보');
  await tester.tap(
    selected.evaluate().isNotEmpty ? selected : find.byTooltip('상세정보 보기'),
  );
}

/// File cards select on single click and play on double click since 0.3.1.
Future<void> playFileCard(WidgetTester tester, Finder card) async {
  // A real double click stays at one screen position. Re-reading the center
  // after the first tap can follow a moving row and exceed double-tap slop.
  final position = tester.getCenter(card);
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 50));
}
