import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';

void main() {
  test(
    'macOS folder aliases preserve identity, filters and offline state',
    () async {
      final root = await Directory.systemTemp.createTemp('vault-alias-');
      final real = await Directory(p.join(root.path, 'real')).create();
      final alias = await Link(p.join(root.path, 'alias')).create(real.path);
      final library = await Library.open(p.join(root.path, 'db.sqlite'));
      try {
        await File(p.join(real.path, 'sample.mp4')).writeAsBytes([1, 2, 3]);
        await library.connect(real.path);
        final id = (await library.items()).single['id'];
        await library.scan(alias.path);
        expect((await library.items(folder: alias.path)).single['id'], id);
        expect((await library.items()).length, 1);
        await library.disconnect(alias.path);
        expect(await library.folders(), isEmpty);
        expect((await library.items()).single['online'], 0);
        await library.connect(real.path);
        await real.rename(p.join(root.path, 'offline'));
        await library.scan(real.path);
        expect((await library.items()).single['id'], id);
        expect((await library.items()).single['online'], 0);
      } finally {
        await library.close();
        await root.delete(recursive: true);
      }
    },
    skip: !Platform.isMacOS,
  );
  test(
    'recursive scan persists metadata without duplicating or merging copies',
    () async {
      final root = await Directory(
        await Directory.systemTemp.resolveSymbolicLinks(),
      ).createTemp('soft-vault-test-');
      final folder = await Directory(p.join(root.path, '자료 🎬')).create();
      final nested = await Directory(p.join(folder.path, 'nested')).create();
      await File(p.join(nested.path, '영상.mkv')).writeAsBytes([1, 2, 3]);
      await File(p.join(folder.path, '복사본.mkv')).writeAsBytes([1, 2, 3]);
      await File(p.join(folder.path, 'ignore.txt')).writeAsString('not media');
      final database = p.join(root.path, 'catalog.sqlite');
      var library = await Library.open(database);
      try {
        await library.connect(folder.path);
        final items = await library.items();
        expect(items.length, 2);
        final id = items.first['id'] as int;
        await library.edit(id, {
          'rating': 5,
          'tags': '여행',
          'description': '두 줄\n설명',
        });
        await library.scan(folder.path);
        expect((await library.items()).length, 2);
        await library.close();
        library = await Library.open(database);
        expect((await library.items(query: '여행')).single['rating'], 5);
        await expectLater(library.edit(id, {'rating': 6}), throwsA(anything));
        await expectLater(
          library.edit(id, {'path': 'bad'}),
          throwsArgumentError,
        );
        await folder.rename(p.join(root.path, 'offline'));
        await library.scan(folder.path);
        expect((await library.items()).length, 2);
      } finally {
        await library.close();
        await root.delete(recursive: true);
      }
    },
  );
}
