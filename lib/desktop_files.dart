import 'package:flutter/services.dart';
import 'library.dart';

class DesktopFiles {
  static const channel = MethodChannel('soft_vault/window');
  static Future<void> reveal(String path) =>
      channel.invokeMethod('reveal', path);
  static Future<void> trash(String path) => channel.invokeMethod('trash', path);
}

extension TrashCatalog on Library {
  Future<void> forgetTrashed(int id) => db.transaction((tx) async {
    for (final table in ['media_actors', 'media_tags', 'bookmarks']) {
      await tx.delete(table, where: 'media_id=?', whereArgs: [id]);
    }
    await tx.delete('media', where: 'id=?', whereArgs: [id]);
  });
}
