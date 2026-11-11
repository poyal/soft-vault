import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/file_dialogs.dart';
import 'package:soft_vault/file_jobs.dart';
import 'package:soft_vault/playback_history_dialog.dart';
import 'package:soft_vault/settings_components.dart';

void main() {
  testWidgets(
    'folder, jobs and playback history dialogs fit minimum window and enlarged text',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('utility-ui-'),
      ))!;
      final library = (await tester.runAsync(
        () => Library.open(dir.path + '/db.sqlite'),
      ))!;
      try {
        await tester.binding.setSurfaceSize(const Size(1000, 700));
        for (final scale in [1.0, 1.25, 1.5]) {
          for (final type in ['folders', 'jobs', 'history']) {
            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey(type + scale.toString()),
                theme: ThemeData.dark(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: SettingsTheme(child: child!),
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      child: const Text('open'),
                      onPressed: () {
                        switch (type) {
                          case 'folders':
                            showFolderManager(context, library, () async {});
                          case 'jobs':
                            showFileJobs(
                              context,
                              library,
                              FileJobs(library),
                              [],
                              prepare: () async {},
                              changed: () async {},
                            );
                          case 'history':
                            showDialog<void>(
                              context: context,
                              builder: (_) => PlaybackHistoryDialog(
                                library: library,
                                item: {'id': 1, 'title': '긴 한글 제목 ' * 20},
                              ),
                            );
                        }
                      },
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('open'));
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 150));
            });
            await tester.pump();
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 150));
            });
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: type + scale.toString(),
            );
            await tester.tap(find.text('닫기'));
            await tester.pumpAndSettle();
          }
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.binding.setSurfaceSize(null);
        await tester.runAsync(library.close);
        await tester.runAsync(() => dir.delete(recursive: true));
      }
    },
  );
}
