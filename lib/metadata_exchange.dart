import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'library.dart';
import 'catalog_schema.dart';

class MetadataProposal {
  final Map<String, dynamic> request;
  final Map<int, Map<String, Object?>> changes;
  final int missing;
  MetadataProposal(this.request, this.changes, this.missing);
}

class MetadataExchange {
  final Library library;
  final Future<void> Function(File)? backupWriter;
  MetadataExchange(this.library, {this.backupWriter});
  static const key = 'metadata_exchange_request_v1';
  static const fields = ['title', 'actors', 'tags', 'description'];
  static const guide = '''아래 전체 영상 목록의 제목·배우·태그·설명을 조사하고 보완해 주세요.
파일명과 기존 정보를 단서로 사용하되 동일 작품인지 확인해 주세요. 확인할 수 없는 정보나 배우 이름은 추측하지 마세요. 확인되지 않은 필드는 생략하세요.
모든 영상을 한 JSON의 videos 배열로 반환하세요. version, requestId, 각 영상의 id는 그대로 유지하세요. 파일명은 식별 참고용입니다.
각 영상의 변경 제안은 title(문자열), actors(문자열 배열), tags(문자열 배열), description(문자열)만 사용하세요. 배우·태그는 추가분이 아닌 최종 전체 목록으로 작성하세요.
개인 평점이나 재생 기록은 작성하지 마세요. 설명 밖에 해설을 덧붙이지 말고 JSON만 반환하세요.
반환 예시: {"version":1,"requestId":"입력의 requestId","videos":[{"id":"입력의 id","title":"확인한 제목","actors":["확인한 배우"],"tags":["태그"],"description":"확인한 설명"}]}''';

  Future<Map<String, dynamic>?> load() async {
    final value = await library.readSetting(key);
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  Future<Map<String, dynamic>> create() async {
    final rows = await library.db.query(
      'media',
      where: "type='video'",
      orderBy: 'id',
    );
    final request = <String, dynamic>{
      'version': 1,
      'requestId': List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      'created': DateTime.now().toIso8601String(),
      'rows': [
        for (final row in rows)
          {
            'id': row['id'],
            'filename': p.basename(row['path'] as String),
            'fingerprint': row['fingerprint'],
            for (final field in fields) field: row[field],
          },
      ],
    };
    await library.setting(key, request);
    return request;
  }

  String encode(Map<String, dynamic> request) =>
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'requestId': request['requestId'],
        'videos': [
          for (final row in request['rows'])
            {
              'id': 'video-${row['id']}',
              'filename': row['filename'],
              'title': row['title'],
              'actors': names(row['actors'] as String),
              'tags': names(row['tags'] as String),
              'description': row['description'],
            },
        ],
      });

  MetadataProposal parse(String input, Map<String, dynamic> request) {
    var text = input.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    final data = jsonDecode(text);
    if (data is! Map ||
        data['version'] != 1 ||
        data['requestId'] != request['requestId'] ||
        data['videos'] is! List) {
      throw const FormatException(
        '현재 내보내기 요청의 version·requestId·videos가 필요합니다.',
      );
    }
    final originals = {
      for (final row in request['rows']) 'video-${row['id']}': row,
    };
    final seen = <String>{};
    final changes = <int, Map<String, Object?>>{};
    for (final entry in data['videos']) {
      if (entry is! Map ||
          entry['id'] is! String ||
          !originals.containsKey(entry['id'])) {
        throw const FormatException('알 수 없는 영상 식별값이 있습니다. 원본 id를 유지해 주세요.');
      }
      final token = entry['id'] as String;
      if (!seen.add(token)) throw FormatException('$token: 영상이 중복되었습니다.');
      if (entry.keys.any((k) => !['id', 'filename', ...fields].contains(k))) {
        throw FormatException('$token: 지원하지 않는 필드가 있습니다.');
      }
      final old = originals[token];
      final delta = <String, Object?>{};
      for (final field in fields) {
        final value = entry[field];
        if (value == null) continue;
        String next;
        if (field == 'actors' || field == 'tags') {
          if (value is! List || value.any((v) => v is! String))
            throw FormatException('$token · $field: 문자열 배열이 필요합니다.');
          if (value.any((v) => (v as String).contains(',')))
            throw FormatException(
              '$token · $field: 이름은 쉼표로 합치지 말고 배열 항목으로 나눠 주세요.',
            );
          next = value
              .cast<String>()
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toSet()
              .join(', ');
        } else {
          if (value is! String)
            throw FormatException('$token · $field: 문자열이 필요합니다.');
          next = value.trim();
        }
        if (next.isNotEmpty && next != old[field]) delta[field] = next;
      }
      if (delta.isNotEmpty) changes[old['id'] as int] = delta;
    }
    return MetadataProposal(request, changes, originals.length - seen.length);
  }

  Future<void> apply(
    MetadataProposal proposal,
    Map<int, Set<String>> selection,
  ) => library.fileOperation(() async {
    final backup = File(
      p.join(
        p.dirname(library.db.path),
        'before-ai-metadata-${DateTime.now().microsecondsSinceEpoch}.json',
      ),
    );
    await (backupWriter ?? library.exportTo)(backup);
    await library.db.transaction((tx) async {
      final stored = await tx.query(
        'settings',
        where: 'key=?',
        whereArgs: [key],
      );
      if (stored.isEmpty ||
          (jsonDecode(stored.single['value'] as String))['requestId'] !=
              proposal.request['requestId']) {
        throw StateError('내보내기 요청이 바뀌었습니다. 새 요청의 결과를 입력해 주세요.');
      }
      for (final original in proposal.request['rows']) {
        final id = original['id'] as int;
        final chosen = selection[id] ?? {};
        final delta = proposal.changes[id];
        if (chosen.isEmpty || delta == null) continue;
        final rows = await tx.query('media', where: 'id=?', whereArgs: [id]);
        if (rows.isEmpty ||
            [
              ...fields,
              'fingerprint',
            ].any((f) => rows.single[f] != original[f])) {
          throw StateError(
            '${original['filename']}: 내보낸 뒤 정보가 변경되었습니다. 새 요청을 만들어 다시 비교해 주세요.',
          );
        }
        final values = {
          for (final f in chosen)
            if (delta.containsKey(f)) f: delta[f],
        };
        if (values.isEmpty) continue;
        await tx.update('media', values, where: 'id=?', whereArgs: [id]);
        for (final f in ['actors', 'tags']) {
          if (values.containsKey(f))
            await setRelations(tx, id, f, values[f] as String);
        }
      }
      await tx.delete('settings', where: 'key=?', whereArgs: [key]);
    });
  });
}
