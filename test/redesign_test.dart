import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/detail_dialog.dart';
import 'package:soft_vault/file_list.dart';

void main() {
  test(
    'v4 migration preserves summary, tags and writes a recovery backup',
    () async {
      final root = await Directory.systemTemp.createTemp('summary-v5-');
      Library? library;
      try {
        final media = await Directory('${root.path}/media').create();
        await File('${media.path}/sample.mp4').writeAsBytes([1, 2, 3]);
        final path = '${root.path}/vault.sqlite';
        library = await Library.open(path);
        await library.connect(media.path);
        final id = (await library.items()).single['id'] as int;
        await library.edit(id, {'tags': 'one, two', 'rating': 4});
        await library.db.execute(
          'CREATE TABLE playback_history(id INTEGER PRIMARY KEY, media_id INTEGER, started_at INTEGER, start_position_ms INTEGER)',
        );
        await library.db.insert('playback_history', {
          'media_id': id,
          'started_at': 100,
          'start_position_ms': 900,
        });
        await library.db.update(
          'media',
          {'resume_ms': 900, 'watched': 1},
          where: 'id=?',
          whereArgs: [id],
        );
        await library.db.execute('PRAGMA user_version=4');
        await library.close();
        library = await Library.open(path);
        final row = (await library.items()).single;
        expect(row['play_count'], 1);
        expect(row['last_played'], 100);
        expect(row['resume_ms'], 900);
        expect(row['watched'], 1);
        expect(row['tags'], 'one, two');
        expect(
          await library.db.rawQuery(
            "SELECT name FROM sqlite_master WHERE name='playback_history'",
          ),
          isEmpty,
        );
        expect(
          root.listSync().where((f) => f.path.contains('before-v5')),
          hasLength(1),
        );
      } finally {
        await library?.close();
        await root.delete(recursive: true);
      }
    },
  );
  test('display title removes only exact actor suffix', () {
    expect(
      displayTitle({'title': 'ABC-001 · Name', 'actors': 'Name'}),
      'ABC-001',
    );
    expect(
      displayTitle({'title': 'Name in a title', 'actors': 'Name'}),
      'Name in a title',
    );
  });
  testWidgets('detail saves rating without editing and fits narrow window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    int? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailEditor(
            item: {
              'id': 1,
              'title': 'ABC-001 · Name',
              'actors': 'Name',
              'tags': 'one',
              'path': 'C:/sample.mp4',
              'folder': 'C:/',
              'rating': null,
            },
            play: () {},
            rename: () {},
            external: () {},
            relink: () {},
            onRating: (value) async {
              saved = value;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('4점'));
    await tester.pumpAndSettle();
    expect(saved, 4);
    expect(find.text('정보 편집'), findsOneWidget);
    expect(find.text('재생 이력'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });
}
