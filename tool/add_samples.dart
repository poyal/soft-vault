import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';
import 'package:soft_vault/advanced_catalog.dart';

/// Adds real, playable local examples without replacing existing catalog entries.
/// Usage: dart run tool/add_samples.dart <existing vault.sqlite>
Future<void> main(List<String> args) async {
  if (args.length != 1 || !await File(args.single).exists()) {
    throw ArgumentError('Pass the existing application catalog path.');
  }
  final repo = Directory.current.path;
  final root = p.join(repo, 'sample-media');
  final photos = await Directory(p.join(root, '샘플 사진')).create(recursive: true);
  final videos = await Directory(p.join(root, '샘플 영상')).create(recursive: true);
  final thumbs = await Directory(
    p.join(root, '.thumbnails'),
  ).create(recursive: true);
  final bin = p.join(
    repo,
    'build',
    'package',
    'SoftVault-Windows',
    'app',
    'tools',
  );
  Future<String> ff(String tool, List<String> arguments) async {
    final result = await Process.run(p.join(bin, '$tool.exe'), arguments);
    if (result.exitCode != 0) throw StateError('$tool: ${result.stderr}');
    return '${result.stdout}';
  }

  const titles = {
    'alpine': '산맥 위의 아침',
    'lake': '고요한 호수',
    'forest': '숲속의 빛',
    'coast': '파도가 지난 자리',
    'desert': '모래 위의 시간',
    'night': '도시의 밤',
    'road': '길 위의 오후',
    'ridge': '능선을 따라',
  };
  final entries = <String, Map<String, Object?>>{};
  var index = 0;
  for (final entry in titles.entries) {
    final target = p.join(photos.path, '${entry.key}.jpg');
    if (!await File(target).exists()) {
      await File(
        p.join(repo, 'design', 'assets', '${entry.key}.jpg'),
      ).copy(target);
    }
    entries[target] = {
      'title': '[샘플] ${entry.value}',
      'rating': 3 + index++ % 3,
      'tags': entry.key == 'night' ? '샘플, 사진, 도시' : '샘플, 사진, 자연',
      'description':
          '라이브러리 탐색·평점·태그 편집을 체험하는 샘플 사진입니다. 원본 출처는 sample-media/README.txt에 있습니다.',
    };
  }
  for (final name in ['alpine', 'lake', 'coast']) {
    final target = p.join(videos.path, '$name-preview.mp4');
    if (!await File(target).exists()) {
      await ff('ffmpeg', [
        '-nostdin',
        '-v',
        'error',
        '-n',
        '-i',
        p.join(photos.path, '$name.jpg'),
        '-vf',
        "scale=1920:-2,zoompan=z='min(zoom+0.0006,1.15)':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=240:s=1280x720:fps=30",
        '-t',
        '8',
        '-an',
        '-c:v',
        'libx264',
        '-preset',
        'veryfast',
        '-crf',
        '25',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        target,
      ]);
    }
    entries[target] = {
      'title': '[샘플 영상] ${titles[name]}',
      'rating': 5,
      'tags': '샘플, 영상, 자연',
      'description':
          '샘플 사진에 느린 확대 효과를 적용한 8초 무음 영상입니다. 재생·장면 메모·대표 썸네일 선택을 체험할 수 있습니다.',
    };
  }
  final trailer = p.join(videos.path, 'sintel-trailer.mp4');
  if (!await File(trailer).exists()) {
    await File(p.join(repo, '.tools', 'fixtures', 'trailer.mp4')).copy(trailer);
  }
  entries[trailer] = {
    'title': '[샘플 영상] Sintel 예고편',
    'rating': 4,
    'tags': '샘플, 영상, 애니메이션',
    'description':
        'Blender Foundation의 Sintel 예고편 샘플입니다. 실제 영상·음성 재생과 탐색을 체험할 수 있으며 시작 음량은 0%입니다.',
  };
  await File(p.join(root, 'README.txt')).writeAsString(
    'Soft Vault local samples\n\nPhotos: existing design/assets images. Original Unsplash photo links are recorded in plan.md, section 11.\nThe three scenic MP4s are eight-second silent zoom animations made from those photos.\nSintel trailer: existing .tools/fixtures/trailer.mp4, Blender Foundation.\n\nThese are actual image/video files. Ratings, tags, collections and scene notes are demonstration metadata.\nDisconnecting the sample folders in the app preserves the original files.\n',
  );
  final library = await Library.open(args.single);
  try {
    final oldPaths = (await library.items()).map((row) => row['path']).toSet();
    final backup = File(
      p.join(
        repo,
        'build',
        'backups',
        'before-samples-${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    await backup.parent.create(recursive: true);
    await library.exportTo(backup);
    if ((await library.folders()).contains(photos.path)) {
      await library.disconnect(photos.path);
    }
    await library.connect(videos.path);
    var added = 0;
    for (final row in await library.items()) {
      final path = row['path'] as String;
      if (!entries.containsKey(path) || oldPaths.contains(path)) continue;
      final id = row['id'] as int;
      await library.edit(id, entries[path]!);
      if (row['type'] == 'image') {
        await library.db.update(
          'media',
          {'thumbnail': path},
          where: 'id=?',
          whereArgs: [id],
        );
      } else {
        final data =
            jsonDecode(
                  await ff('ffprobe', [
                    '-v',
                    'error',
                    '-show_format',
                    '-show_streams',
                    '-of',
                    'json',
                    path,
                  ]),
                )
                as Map<String, dynamic>;
        final video = (data['streams'] as List).firstWhere(
          (s) => s['codec_type'] == 'video',
        );
        final duration = double.parse('${data['format']['duration']}');
        final thumb = p.join(
          thumbs.path,
          '${p.basenameWithoutExtension(path)}.jpg',
        );
        await ff('ffmpeg', [
          '-nostdin',
          '-v',
          'error',
          '-y',
          '-ss',
          '1',
          '-i',
          path,
          '-frames:v',
          '1',
          '-vf',
          'scale=960:-2',
          thumb,
        ]);
        await library.db.update(
          'media',
          {
            'thumbnail': thumb,
            'duration': duration,
            'codec': video['codec_name'],
            'resolution': '${video['width']} × ${video['height']}',
          },
          where: 'id=?',
          whereArgs: [id],
        );
        await library.saveBookmark(
          id,
          const Duration(seconds: 3),
          title: '샘플 장면',
          note: '이 장면으로 이동하거나 메모를 수정해 보세요.',
        );
      }
      added++;
    }
    for (final entry in {
      '샘플 · 전체': const MediaCriteria(tags: '샘플'),
      '샘플 · 별 다섯 개': const MediaCriteria(tags: '샘플', minimumRating: 5),
    }.entries) {
      if ((await library.db.query(
        'collections',
        where: 'name=?',
        whereArgs: [entry.key],
      )).isEmpty) {
        await library.saveCollection(entry.key, entry.value);
      }
    }
    final samples = (await library.items())
        .where((row) => entries.containsKey(row['path']))
        .toList();
    if (samples.length != 4 ||
        samples.any(
          (row) => row['online'] != 1 || (row['thumbnail'] as String).isEmpty,
        )) {
      throw StateError('Sample verification failed.');
    }
    for (final row in samples.where((row) => row['type'] == 'video')) {
      await ff('ffmpeg', [
        '-nostdin',
        '-v',
        'error',
        '-i',
        row['path'] as String,
        '-f',
        'null',
        '-',
      ]);
    }
    stdout.writeln(
      jsonEncode({
        'added': added,
        'samples': samples.length,
        'images': 0,
        'videos': 4,
        'decodedAllVideos': true,
        'backup': backup.path,
        'folder': root,
      }),
    );
  } finally {
    await library.close();
  }
}
