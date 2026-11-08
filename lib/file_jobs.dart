import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'library.dart';

/// Native publish with NO replacement: Dart's rename can overwrite a file.
void publishNoReplace(String source, String destination) {
  if (Platform.isWindows) {
    final move = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<
          Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32),
          int Function(Pointer<Utf16>, Pointer<Utf16>, int)
        >('MoveFileExW');
    final from = source.toNativeUtf16();
    final to = destination.toNativeUtf16();
    try {
      if (move(from, to, 0) == 0)
        throw FileSystemException(
          '파일을 이동할 수 없습니다. 목적지·권한을 확인하세요.',
          destination,
        );
    } finally {
      calloc.free(from);
      calloc.free(to);
    }
  } else {
    final link = DynamicLibrary.process()
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
          int Function(Pointer<Utf8>, Pointer<Utf8>)
        >('link');
    final from = source.toNativeUtf8();
    final to = destination.toNativeUtf8();
    try {
      if (link(from, to) != 0)
        throw FileSystemException('목적지 파일을 만들 수 없습니다.', destination);
      File(source).deleteSync();
    } finally {
      calloc.free(from);
      calloc.free(to);
    }
  }
}

class FileJobs {
  final Library library;
  final void Function(String phase)? checkpoint;
  bool cancelled = false;
  bool running = false;
  FileJobs(this.library, {this.checkpoint});
  Future<List<Map<String, Object?>>> history() =>
      library.db.query('jobs', orderBy: 'id DESC');
  Future<void> state(int id, String value, [String error = '']) async {
    await library.db.update(
      'jobs',
      {'state': value, 'error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> move(
    List<int> ids,
    String root, {
    bool autoRename = false,
    String? filename,
    bool forceCopy = false,
    void Function(int done, int total)? progress,
  }) async {
    if (running) throw StateError('파일 작업이 이미 진행 중입니다.');
    running = true;
    cancelled = false;
    try {
      await library.fileOperation(
        () => _move(
          ids,
          root,
          autoRename: autoRename,
          filename: filename,
          forceCopy: forceCopy,
          progress: progress,
        ),
      );
    } finally {
      running = false;
    }
  }

  Future<void> _move(
    List<int> ids,
    String root, {
    bool autoRename = false,
    String? filename,
    bool forceCopy = false,
    void Function(int done, int total)? progress,
  }) async {
    final resolved = await Directory(root).resolveSymbolicLinks();
    if (!(await library.folders()).any(
      (folder) => p.equals(folder, resolved) || p.isWithin(folder, resolved),
    ))
      throw ArgumentError('연결된 폴더를 선택하세요.');
    if (filename != null &&
        (ids.length != 1 ||
            filename.isEmpty ||
            filename != p.basename(filename) ||
            RegExp(r'[<>:"/\\|?*]').hasMatch(filename) ||
            filename.endsWith('.') ||
            filename.endsWith(' ')))
      throw ArgumentError('올바른 파일 이름을 입력하세요.');
    running = true;
    cancelled = false;
    try {
      for (var index = 0; index < ids.length; index++) {
        if (cancelled) break;
        final item = (await library.db.query(
          'media',
          where: 'id = ?',
          whereArgs: [ids[index]],
        )).single;
        final source = item['path'] as String;
        var destination = p.join(resolved, filename ?? p.basename(source));
        if (p.equals(source, destination)) {
          progress?.call(index + 1, ids.length);
          continue;
        }
        var number = 1;
        while (autoRename &&
            await FileSystemEntity.type(destination, followLinks: false) !=
                FileSystemEntityType.notFound) {
          destination = p.join(
            resolved,
            '${p.basenameWithoutExtension(filename ?? source)} (${number++})${p.extension(filename ?? source)}',
          );
        }
        final temporary =
            '$destination.softvault-${DateTime.now().microsecondsSinceEpoch}.part';
        final id = await library.db.insert('jobs', {
          'media_id': item['id'],
          'source': source,
          'destination': destination,
          'temporary': temporary,
          'fingerprint': '',
          'state': 'planned',
          'created': DateTime.now().millisecondsSinceEpoch,
        });
        var published = false;
        try {
          if (await FileSystemEntity.type(destination, followLinks: false) !=
              FileSystemEntityType.notFound) {
            await state(id, 'skipped', '같은 이름의 파일이 있어 건너뛰었습니다.');
            continue;
          }
          final digest = await Library.fingerprint(File(source));
          await library.db.update(
            'jobs',
            {'fingerprint': digest},
            where: 'id = ?',
            whereArgs: [id],
          );
          checkpoint?.call('planned');
          var renamed = false;
          if (!forceCopy &&
              p.rootPrefix(source).toLowerCase() ==
                  p.rootPrefix(destination).toLowerCase()) {
            await state(id, 'publishing_move');
            try {
              publishNoReplace(source, destination);
              renamed = true;
            } on FileSystemException {
              if (await File(destination).exists()) rethrow;
            }
          }
          if (!renamed) {
            await state(id, 'copying');
            await File(temporary).create(exclusive: true);
            final output = File(temporary).openWrite();
            try {
              await for (final bytes in File(source).openRead()) {
                if (cancelled) throw const _Cancelled();
                output.add(bytes);
                await output.flush();
                checkpoint?.call('copy_chunk');
              }
            } finally {
              await output.close();
            }
            if (await Library.fingerprint(File(temporary)) != digest ||
                await Library.fingerprint(File(source)) != digest)
              throw StateError('복사 중 원본이 변경되었거나 검증에 실패했습니다.');
            if (cancelled) throw const _Cancelled();
            checkpoint?.call('copied');
            await state(id, 'publishing_copy');
            publishNoReplace(temporary, destination);
          }
          published = true;
          await state(id, 'published');
          checkpoint?.call('published');
          await _finish(
            (await library.db.query(
              'jobs',
              where: 'id = ?',
              whereArgs: [id],
            )).single,
          );
        } on _Cancelled {
          if (await File(temporary).exists()) await File(temporary).delete();
          await state(id, 'cancelled', '미완료 복사를 취소했습니다.');
        } catch (e) {
          await state(id, published ? 'cleanup_failed' : 'failed', '$e');
        } finally {
          progress?.call(index + 1, ids.length);
        }
      }
    } finally {
      running = false;
    }
  }

  Future<void> _finish(Map<String, Object?> job) async {
    final destination = File(job['destination'] as String);
    final source = File(job['source'] as String);
    final digest = job['fingerprint'] as String;
    if (digest.isEmpty ||
        !await destination.exists() ||
        await Library.fingerprint(destination) != digest) {
      throw StateError('목적지 무결성을 확인할 수 없어 원본을 유지합니다.');
    }
    final stat = await destination.stat();
    final roots =
        (await library.folders())
            .where((root) => p.isWithin(root, destination.path))
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    final records = await library.db.query(
      'media',
      where: 'id = ?',
      whereArgs: [job['media_id']],
    );
    if (records.isEmpty ||
        ![job['source'], job['destination']].contains(records.single['path'])) {
      throw StateError('파일 위치가 다른 작업에서 변경되어 자동 복구를 중단했습니다.');
    }
    await library.db.update(
      'media',
      {
        'path': destination.path,
        'folder': roots.isEmpty ? p.dirname(destination.path) : roots.first,
        'fingerprint': digest,
        'size': stat.size,
        'modified': stat.modified.millisecondsSinceEpoch,
        'online': 1,
      },
      where: 'id = ?',
      whereArgs: [job['media_id']],
    );
    if (await source.exists()) {
      if (await Library.fingerprint(source) != digest)
        throw StateError('원본이 변경되어 삭제하지 않았습니다.');
      await source.delete();
    }
    await state(job['id'] as int, 'done');
  }

  Future<void> recover() async {
    if (running) return;
    for (final job in await history()) {
      if (['done', 'skipped', 'cancelled'].contains(job['state'])) continue;
      try {
        final wasPublished =
            ['published', 'cleanup_failed'].contains(job['state']) ||
            (job['state'] == 'publishing_move' &&
                !await File(job['source'] as String).exists()) ||
            (job['state'] == 'publishing_copy' &&
                !await File(job['temporary'] as String).exists());
        if (wasPublished) {
          await _finish(job);
        } else {
          final temp = File(job['temporary'] as String);
          if (await temp.exists()) await temp.delete();
          await state(
            job['id'] as int,
            'failed',
            '중단된 작업입니다. 원본을 보존했습니다. 다시 시도하세요.',
          );
        }
      } catch (e) {
        await state(job['id'] as int, 'cleanup_failed', '$e');
      }
    }
  }

  Future<void> retry() async {
    await recover();
    for (final job in await history()) {
      if (job['state'] == 'failed' &&
          !await File(job['destination'] as String).exists()) {
        await move(
          [job['media_id'] as int],
          p.dirname(job['destination'] as String),
          filename: p.basename(job['destination'] as String),
        );
        final item = await library.db.query(
          'media',
          where: 'id = ?',
          whereArgs: [job['media_id']],
        );
        if (item.isNotEmpty && item.single['path'] == job['destination'])
          await state(job['id'] as int, 'done');
      }
    }
  }
}

class _Cancelled {
  const _Cancelled();
}
