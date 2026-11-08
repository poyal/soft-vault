import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'library.dart';

class MediaTools {
  final Library library;
  final Directory cache;
  final String bin;
  MediaTools(this.library, this.cache, this.bin);
  Future<void> _previewQueue = Future.value();
  Future<String> frame(Map<String, Object?> item, double seconds) async {
    if (item['type'] != 'video' || item['online'] != 1)
      throw StateError('온라인 영상이 필요합니다.');
    await cache.create(recursive: true);
    final target = p.join(
      cache.path,
      'frame-${item['id']}-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final result = await run('ffmpeg', [
      '-nostdin',
      '-v',
      'error',
      '-ss',
      seconds
          .clamp(
            0,
            ((item['duration'] as num).toDouble() - .1).clamp(
              0,
              double.infinity,
            ),
          )
          .toString(),
      '-i',
      item['path'] as String,
      '-frames:v',
      '1',
      '-vf',
      'scale=960:-2',
      target,
    ]);
    if (result.exitCode != 0 || !await File(target).exists())
      throw StateError('장면 이미지를 만들 수 없습니다: ${result.stderr}');
    return target;
  }

  Future<void> setThumbnail(int id, String source) async {
    await cache.create(recursive: true);
    final extension = p.extension(source).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp', '.bmp'].contains(extension))
      throw ArgumentError('지원하는 이미지 파일을 선택하세요.');
    final target = p.join(
      cache.path,
      'chosen-$id-${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(source).copy(target);
    await library.db.update(
      'media',
      {'thumbnail': target, 'custom_thumbnail': 1},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> resetThumbnail(int id) async {
    await library.db.update(
      'media',
      {'thumbnail': '', 'custom_thumbnail': 0},
      where: 'id=?',
      whereArgs: [id],
    );
    await enrich();
  }

  Future<String> preview(Map<String, Object?> item) {
    final next = _previewQueue.then((_) async {
      if (item['type'] != 'video' || item['online'] != 1)
        throw StateError('온라인 영상이 필요합니다.');
      await cache.create(recursive: true);
      final target = p.join(
        cache.path,
        'preview-${item['id']}-${item['modified']}.webp',
      );
      if (await File(target).exists()) return target;
      final result = await run('ffmpeg', [
        '-nostdin',
        '-v',
        'error',
        '-ss',
        (((item['duration'] as num).toDouble() * .1).clamp(0, 30)).toString(),
        '-i',
        item['path'] as String,
        '-an',
        '-t',
        '3',
        '-vf',
        'fps=6,scale=320:-2',
        '-loop',
        '0',
        '-c:v',
        'libwebp_anim',
        '-quality',
        '55',
        target,
      ]);
      if (result.exitCode != 0) {
        if (await File(target).exists()) await File(target).delete();
        throw StateError('영상 미리보기를 만들 수 없습니다.');
      }
      return target;
    });
    _previewQueue = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  static String bundledBin() {
    final bundled = p.join(p.dirname(Platform.resolvedExecutable), 'tools');
    if (Directory(bundled).existsSync()) return bundled;
    if (Platform.isMacOS) {
      return p.join(Directory.current.path, '.tools', 'ffmpeg', 'bin');
    }
    return p.join(
      Directory.current.path,
      '.tools',
      'ffmpeg',
      'extracted',
      'ffmpeg-9.0.2-essentials_build',
      'bin',
    );
  }

  Future<ProcessResult> run(String tool, List<String> args) async {
    final process = await Process.start(
      p.join(bin, '$tool${Platform.isWindows ? '.exe' : ''}'),
      args,
    );
    final output = process.stdout.transform(utf8.decoder).join();
    final error = process.stderr.transform(utf8.decoder).join();
    try {
      final code = await process.exitCode.timeout(const Duration(seconds: 45));
      return ProcessResult(process.pid, code, await output, await error);
    } on TimeoutException {
      process.kill();
      rethrow;
    }
  }

  Future<void> enrich() async {
    await cache.create(recursive: true);
    for (final item in await library.items()) {
      if (item['online'] != 1) continue;
      if (item['custom_thumbnail'] == 1 &&
          File(item['thumbnail'] as String).existsSync())
        continue;
      if ((item['thumbnail'] as String).isNotEmpty &&
          File(item['thumbnail'] as String).existsSync())
        continue;
      final path = item['path'] as String;
      try {
        final probe = await run('ffprobe', [
          '-v',
          'error',
          '-show_format',
          '-show_streams',
          '-of',
          'json',
          path,
        ]);
        if (probe.exitCode != 0) continue;
        final data = jsonDecode(probe.stdout as String) as Map<String, dynamic>;
        final streams = (data['streams'] as List).cast<Map<String, dynamic>>();
        final videos = streams.where((s) => s['codec_type'] == 'video');
        final video = videos.isEmpty ? <String, dynamic>{} : videos.first;
        final thumb = p.join(
          cache.path,
          '${item['id']}-${item['modified']}.jpg',
        );
        final duration =
            double.tryParse('${data['format']?['duration'] ?? 0}') ?? 0;
        final extraction = await run('ffmpeg', [
          '-nostdin',
          '-v',
          'error',
          '-y',
          '-ss',
          (duration * .1).clamp(0, 30).toString(),
          '-i',
          path,
          '-frames:v',
          '1',
          '-vf',
          'scale=480:-2',
          thumb,
        ]);
        await library.db.update(
          'media',
          {
            'duration': duration,
            'codec': video['codec_name'] ?? '',
            'resolution': video['width'] == null
                ? ''
                : '${video['width']} × ${video['height']}',
            'thumbnail': extraction.exitCode == 0 ? thumb : '',
          },
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      } on ProcessException {
        rethrow;
      } on TimeoutException {
        continue;
      } on FormatException {
        continue;
      }
    }
  }
}
