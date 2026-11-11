import 'design.dart';
import 'package:flutter/material.dart';
import 'advanced_catalog.dart';
import 'library.dart';

String sceneTime(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class ScenesDialog extends StatefulWidget {
  final Library library;
  final int mediaId;
  final Duration Function() position;
  final ValueChanged<Duration> jump;
  const ScenesDialog({
    super.key,
    required this.library,
    required this.mediaId,
    required this.position,
    required this.jump,
  });
  @override
  State<ScenesDialog> createState() => _ScenesDialogState();
}

class _ScenesDialogState extends State<ScenesDialog> {
  List<Map<String, Object?>> marks = [];
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final rows = await widget.library.bookmarks(widget.mediaId);
    if (mounted) setState(() => marks = rows);
  }

  Future<void> edit([Map<String, Object?>? mark]) async {
    final position = mark == null
        ? widget.position()
        : Duration(milliseconds: mark['position_ms'] as int);
    final title = TextEditingController(
      text:
          mark?['title'] as String? ??
          '장면 ${sceneTime(position.inMilliseconds)}',
    );
    final note = TextEditingController(text: mark?['note'] as String? ?? '');
    final time = TextEditingController(
      text: (position.inMilliseconds / 1000).toStringAsFixed(1),
    );
    String? issue;
    final saved = await showDeckDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('장면 북마크 · 메모'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '장면 이름'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: time,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '위치 (초)'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '이 장면의 메모'),
                ),
                if (issue != null)
                  Text(issue!, style: const TextStyle(color: Colors.orange)),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final seconds = double.tryParse(time.text);
                  if (seconds == null || !seconds.isFinite || seconds < 0)
                    throw ArgumentError('올바른 초 단위를 입력하세요.');
                  await widget.library.saveBookmark(
                    widget.mediaId,
                    Duration(milliseconds: (seconds * 1000).round()),
                    id: mark?['id'] as int?,
                    title: title.text,
                    note: note.text,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  update(() => issue = '$e');
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    // Let the route's closing animation release its text fields.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    title.dispose();
    note.dispose();
    time.dispose();
    if (saved == true) await load();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('장면 북마크'),
    content: SizedBox(
      width: 680,
      height: 400,
      child: Column(
        children: [
          if (error != null) Text(error!),
          Expanded(
            child: marks.isEmpty
                ? const Center(child: Text('기억할 장면을 시간과 메모로 남겨보세요.'))
                : ListView(
                    children: marks
                        .map(
                          (mark) => ListTile(
                            leading: Text(
                              sceneTime(mark['position_ms'] as int),
                              style: const TextStyle(color: Color(0xff87b8d8)),
                            ),
                            title: Text(mark['title'] as String),
                            subtitle: Text(
                              mark['note'] as String,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              widget.jump(
                                Duration(
                                  milliseconds: mark['position_ms'] as int,
                                ),
                              );
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '장면 편집',
                                  onPressed: () => edit(mark),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '장면 삭제',
                                  onPressed: () async {
                                    await widget.library.deleteBookmark(
                                      mark['id'] as int,
                                    );
                                    await load();
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                ),
                              ],
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
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
      FilledButton.icon(
        onPressed: () => edit(),
        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
        label: const Text('현재 장면 추가'),
      ),
    ],
  );
}
