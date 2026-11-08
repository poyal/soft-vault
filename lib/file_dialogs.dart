import 'design.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'library.dart';
import 'file_jobs.dart';

Future<void> showFileJobs(
  BuildContext context,
  Library library,
  FileJobs jobs,
  List<int> ids, {
  String? target,
  bool rename = false,
  required Future<void> Function() prepare,
  required Future<void> Function() changed,
}) async {
  final folders = await library.folders();
  if (!context.mounted) return;
  String? destination = target ?? (folders.isEmpty ? null : folders.first);
  if (rename && ids.length == 1) {
    final row = (await library.db.query(
      'media',
      where: 'id = ?',
      whereArgs: [ids.first],
    )).single;
    destination = p.dirname(row['path'] as String);
    if (!folders.contains(destination)) folders.add(destination);
  }
  final filename = TextEditingController();
  if (rename && ids.length == 1)
    filename.text = p.basename(
      (await library.db.query(
            'media',
            where: 'id = ?',
            whereArgs: [ids.first],
          )).single['path']
          as String,
    );
  var autoRename = false, running = false;
  var done = 0;
  String? error;
  var history = await jobs.history();
  if (!context.mounted) return;
  await showDeckDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        Future<void> execute(bool retry) async {
          update(() {
            running = true;
            error = null;
            done = 0;
          });
          try {
            await prepare();
            if (retry) {
              await jobs.retry();
            } else if (destination != null) {
              await jobs.move(
                ids,
                destination!,
                autoRename: autoRename,
                filename: rename ? filename.text : null,
                progress: (value, _) {
                  if (context.mounted) update(() => done = value);
                },
              );
            }
            history = await jobs.history();
            await changed();
          } catch (e) {
            error = '$e';
          } finally {
            if (context.mounted) update(() => running = false);
          }
        }

        return AlertDialog(
          title: Text(rename ? '파일 이름 변경' : '폴더 이동 · 작업 기록'),
          content: SizedBox(
            width: 520,
            height: 460,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ids.length}개 파일 선택 · 원본과 메타데이터를 함께 관리합니다.'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 144,
                  child: folders.isEmpty
                      ? const Center(child: Text('연결 폴더가 필요합니다.'))
                      : ListView(
                          children: [
                            for (final folder in folders)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: destination == folder
                                      ? const Color(0xff2c4a60)
                                      : const Color(0xff223848),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: destination == folder
                                          ? const Color(0xff87b8d8)
                                          : const Color(0xff3b5366),
                                    ),
                                  ),
                                  child: ListTile(
                                    key: ValueKey('move-target:$folder'),
                                    dense: true,
                                    leading: const Icon(
                                      Icons.folder_outlined,
                                      size: 20,
                                    ),
                                    title: Text(p.basename(folder)),
                                    subtitle: Text(
                                      folder,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Icon(
                                      destination == folder
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      size: 18,
                                    ),
                                    onTap: running || rename
                                        ? null
                                        : () => update(
                                            () => destination = folder,
                                          ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                if (rename)
                  TextField(
                    controller: filename,
                    enabled: !running,
                    decoration: const InputDecoration(
                      labelText: '새 파일 이름 (확장자 포함)',
                    ),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('같은 이름이 있으면 자동 이름 변경'),
                  subtitle: const Text('기본 동작은 건너뛰기입니다. 기존 파일을 덮어쓰지 않습니다.'),
                  value: autoRename,
                  onChanged: running
                      ? null
                      : (value) => update(() => autoRename = value!),
                ),
                if (running)
                  LinearProgressIndicator(
                    value: ids.isEmpty ? null : done / ids.length,
                  ),
                if (running) Text('$done / ${ids.length} 처리'),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.orange)),
                const Divider(),
                Expanded(
                  child: history.isEmpty
                      ? const Center(child: Text('아직 작업 기록이 없습니다.'))
                      : ListView(
                          children: history
                              .map(
                                (job) => ListTile(
                                  dense: true,
                                  title: Text(
                                    '${p.basename(job['source'] as String)} → ${p.basename(job['destination'] as String)}',
                                  ),
                                  subtitle: Text(
                                    '${job['state']} ${(job['error'] as String)}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            if (running)
              TextButton(
                onPressed: () => jobs.cancelled = true,
                child: const Text('남은 작업 취소'),
              ),
            if (!running)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            if (!running &&
                history.any(
                  (job) => ['failed', 'cleanup_failed'].contains(job['state']),
                ))
              TextButton(
                onPressed: () => execute(true),
                child: const Text('실패 항목 재시도'),
              ),
            FilledButton(
              onPressed: running || ids.isEmpty || destination == null
                  ? null
                  : () => execute(false),
              child: Text(rename ? '이름 변경' : '이동'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showFolderManager(
  BuildContext context,
  Library library,
  Future<void> Function() changed,
) async {
  var folders = await library.folders();
  String? error;
  if (!context.mounted) return;
  await showDeckDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('연결 폴더'),
        content: SizedBox(
          width: 520,
          height: 260,
          child: ListView(
            children: folders
                .map(
                  (folder) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: const Color(0xff223848),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xff3b5366)),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Directory(folder).existsSync()
                              ? Icons.folder_outlined
                              : Icons.folder_off_outlined,
                        ),
                        title: Text(p.basename(folder)),
                        subtitle: Text(
                          '$folder\n${Directory(folder).existsSync() ? '연결됨' : '오프라인 · 기록 유지'}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xff8a9baa),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: '연결 해제',
                          icon: const Icon(Icons.link_off),
                          onPressed: () async {
                            await changed();
                            await library.disconnect(folder);
                            folders = await library.folders();
                            await changed();
                            if (context.mounted) update(() {});
                          },
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.orange)),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final folder = await getDirectoryPath();
              if (folder == null) return;
              try {
                await library.connect(folder);
                folders = await library.folders();
                await changed();
              } catch (e) {
                error = '$e';
              }
              if (context.mounted) update(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('폴더 연결'),
          ),
        ],
      ),
    ),
  );
}
