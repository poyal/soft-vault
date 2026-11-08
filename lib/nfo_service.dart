import 'dart:io';
import 'package:xml/xml.dart';
import 'library.dart';
import 'advanced_catalog.dart';
import 'catalog_schema.dart';

/// Kodi movie/episode NFO fields; private notes/bookmarks use a softvault element.
/// https://kodi.wiki/view/NFO_files/Movies
class NfoMetadata {
  final Map<String, Object?> fields;
  final int? resumeMs;
  final List<Map<String, Object?>> bookmarks;
  NfoMetadata(this.fields, this.resumeMs, this.bookmarks);
}

class NfoService {
  final Library library;
  NfoService(this.library);
  Future<NfoMetadata> read(File source) async {
    if (await source.length() > 10 * 1024 * 1024)
      throw const FormatException('NFO 파일이 너무 큽니다.');
    return parse(await source.readAsString());
  }

  NfoMetadata parse(String source) {
    if (RegExp(r'<!\s*(DOCTYPE|ENTITY)', caseSensitive: false).hasMatch(source))
      throw const FormatException('외부 선언이 있는 NFO는 지원하지 않습니다.');
    final root = XmlDocument.parse(source).rootElement;
    if (!['movie', 'episodedetails'].contains(root.name.local))
      throw const FormatException('movie 또는 episodedetails NFO가 필요합니다.');
    String? value(XmlElement element, String tag) =>
        element.getElement(tag)?.innerText;
    final fields = <String, Object?>{};
    for (final entry in {'title': 'title', 'plot': 'description'}.entries) {
      final text = value(root, entry.key);
      if (text != null) fields[entry.value] = text;
    }
    final tags = root
        .findElements('tag')
        .map((node) => node.innerText.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (tags.isNotEmpty) fields['tags'] = tags.join(', ');
    final actors = root
        .findElements('actor')
        .map((node) => value(node, 'name')?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
    if (actors.isNotEmpty) fields['actors'] = actors.join(', ');
    final rating = double.tryParse(value(root, 'userrating') ?? '');
    if (rating != null && rating.isFinite)
      fields['rating'] = rating <= 0 ? null : (rating / 2).round().clamp(1, 5);
    final custom = root.getElement('softvault');
    if (custom != null) {
      final note = value(custom, 'note');
      if (note != null) fields['note'] = note;
    }
    final resumeText = root
        .getElement('resume')
        ?.getElement('position')
        ?.innerText;
    final resume = double.tryParse(resumeText ?? '');
    if (resumeText != null &&
        (resume == null || !resume.isFinite || resume < 0))
      throw const FormatException('올바르지 않은 이어보기 위치');
    final marks = <Map<String, Object?>>[];
    for (final node in custom?.findElements('bookmark') ?? <XmlElement>[]) {
      final seconds = double.tryParse(node.getAttribute('seconds') ?? '');
      final title = value(node, 'title') ?? '';
      if (seconds == null ||
          !seconds.isFinite ||
          seconds < 0 ||
          title.trim().isEmpty)
        throw const FormatException('올바르지 않은 장면 북마크');
      marks.add({
        'position_ms': (seconds * 1000).round(),
        'title': title,
        'note': value(node, 'note') ?? '',
      });
    }
    return NfoMetadata(
      fields,
      resume == null ? null : (resume * 1000).round(),
      marks,
    );
  }

  Future<void> apply(int mediaId, NfoMetadata data) async {
    final row = await library.mediaById(mediaId);
    final values = Map<String, Object?>.from(data.fields);
    if (data.resumeMs != null && row['type'] == 'video') {
      final limit = ((row['duration'] as num) * 1000).round();
      values['resume_ms'] = limit > 0
          ? data.resumeMs!.clamp(0, limit)
          : data.resumeMs!;
      values['watched'] = 0;
    }
    await library.db.transaction((tx) async {
      if (values.isNotEmpty)
        await tx.update('media', values, where: 'id=?', whereArgs: [mediaId]);
      for (final kind in ['actors', 'tags']) {
        if (values.containsKey(kind))
          await setRelations(tx, mediaId, kind, values[kind] as String);
      }
      if (row['type'] == 'video') {
        for (final mark in data.bookmarks) {
          final exists = await tx.query(
            'bookmarks',
            where: 'media_id=? AND position_ms=? AND title=? AND note=?',
            whereArgs: [
              mediaId,
              mark['position_ms'],
              mark['title'],
              mark['note'],
            ],
          );
          if (exists.isEmpty)
            await tx.insert('bookmarks', {
              ...mark,
              'media_id': mediaId,
              'created': DateTime.now().millisecondsSinceEpoch,
            });
        }
      }
    });
  }

  Future<String> encode(int mediaId) async {
    final row = await library.mediaById(mediaId);
    final bookmarks = await library.bookmarks(mediaId);
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'movie',
      nest: () {
        builder.element('title', nest: row['title']);
        builder.element('plot', nest: row['description']);
        builder.element(
          'userrating',
          nest: ((row['rating'] as int? ?? 0) * 2).toString(),
        );
        builder.element(
          'runtime',
          nest: ((row['duration'] as num) / 60).round().toString(),
        );
        for (final tag in names(row['tags'] as String)) {
          builder.element('tag', nest: tag);
        }
        for (final actor in names(row['actors'] as String)) {
          builder.element(
            'actor',
            nest: () {
              builder.element('name', nest: actor);
            },
          );
        }
        builder.element(
          'resume',
          nest: () {
            builder.element(
              'position',
              nest: ((row['resume_ms'] as int) / 1000).toString(),
            );
            builder.element('total', nest: '${row['duration']}');
          },
        );
        builder.element(
          'softvault',
          attributes: {'version': '1'},
          nest: () {
            builder.element('note', nest: row['note']);
            for (final mark in bookmarks) {
              builder.element(
                'bookmark',
                attributes: {
                  'seconds': ((mark['position_ms'] as int) / 1000).toString(),
                },
                nest: () {
                  builder.element('title', nest: mark['title']);
                  builder.element('note', nest: mark['note']);
                },
              );
            }
          },
        );
      },
    );
    // Pretty-printing normalizes whitespace inside plots and private notes.
    return builder.buildDocument().toXmlString();
  }

  Future<void> write(int mediaId, File target, {bool overwrite = false}) async {
    final text = await encode(mediaId);
    if (await target.exists()) {
      if (!overwrite)
        throw FileSystemException('같은 이름의 NFO가 있습니다.', target.path);
      final backup = File(
        '${target.path}.backup-${DateTime.now().microsecondsSinceEpoch}',
      );
      await target.copy(backup.path);
      try {
        await target.writeAsString(text, flush: true);
      } catch (_) {
        await backup.copy(target.path);
        rethrow;
      }
    } else {
      await target.create(exclusive: true);
      try {
        await target.writeAsString(text, flush: true);
      } catch (_) {
        await target.delete();
        rethrow;
      }
    }
  }
}
