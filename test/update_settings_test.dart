import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/app_updater.dart';
import 'package:soft_vault/update_settings.dart';

class MemoryUpdater extends AppUpdater {
  MemoryUpdater() : super(Directory('unused'));
  @override
  Future<void> save() async {}
}

void main() {
  testWidgets(
    'ready update offers explicit restart and preserves manual choice',
    (tester) async {
      final updater = MemoryUpdater()
        ..current = '0.1.0'
        ..ready = true
        ..release = {'version': '0.2.0'}
        ..message = '설치 준비 완료';
      AppUpdater.instance = updater;
      var installs = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateSettings(
              install: () async {
                installs++;
              },
            ),
          ),
        ),
      );
      expect(find.text('업데이트 후 재시작'), findsOneWidget);
      expect(installs, 0);
      await tester.tap(find.text('업데이트 후 재시작'));
      expect(installs, 1);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(updater.automatic, false);
      await tester.pumpWidget(const SizedBox());
      AppUpdater.instance = null;
      updater.dispose();
    },
  );
}
