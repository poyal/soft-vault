import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/key_bindings.dart';
import 'package:soft_vault/library.dart';

void main() {
  test(
    'reserved keys and conflicts are rejected, custom mappings persist',
    () async {
      final folder = await Directory(
        await Directory.systemTemp.resolveSymbolicLinks(),
      ).createTemp('vault-keys-');
      final library = await Library.open('${folder.path}/db.sqlite');
      try {
        final keys = KeyBindings(library);
        expect(
          keys.assign('pause', 0, chord(LogicalKeyboardKey.escape)),
          isNotNull,
        );
        expect(
          keys.assign('pause', 0, chord(LogicalKeyboardKey.digit0)),
          isNotNull,
        );
        expect(
          keys.assign('pause', 0, chord(LogicalKeyboardKey.keyM)),
          contains('음소거'),
        );
        expect(keys.assign('pause', 0, chord(LogicalKeyboardKey.keyZ)), isNull);
        await keys.save();
        final reloaded = KeyBindings(library);
        await reloaded.load();
        expect(reloaded.values['pause']!.first, chord(LogicalKeyboardKey.keyZ));
        expect(reloaded.values['back']!.length, 2);
      } finally {
        await library.close();
        await folder.delete(recursive: true);
      }
    },
  );
}
