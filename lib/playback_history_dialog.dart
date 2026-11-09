import 'package:flutter/material.dart';
import 'library.dart';
import 'playback_history.dart';

String formatPlaybackDate(int milliseconds) {
  if (milliseconds <= 0) return '기록 없음';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
}

class PlaybackHistoryDialog extends StatefulWidget {
  final Library library;
  final Map<String, Object?> item;
  const PlaybackHistoryDialog({
    super.key,
    required this.library,
    required this.item,
  });
  @override
  State<PlaybackHistoryDialog> createState() => _PlaybackHistoryDialogState();
}

class _PlaybackHistoryDialogState extends State<PlaybackHistoryDialog> {
  final rows = <Map<String, Object?>>[];
  bool loading = false, more = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await widget.library.playbackHistory(
        widget.item['id'] as int,
        offset: rows.length,
      );
      if (!mounted) return;
      setState(() {
        rows.addAll(next);
        more = next.length == 50;
      });
    } catch (_) {
      if (mounted) setState(() => error = '재생 이력을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('재생 이력'),
    content: SizedBox(
      width: 580,
      height: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.item['title']} · ${widget.item['play_count'] ?? 0}회',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          const Text(
            '횟수와 이력은 기능 추가 이후 앱에서 재생한 기록입니다.\n일시정지·탐색은 횟수를 늘리지 않습니다.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          Expanded(
            child: rows.isEmpty && !loading && error == null
                ? const Center(child: Text('아직 기록된 재생 이력이 없습니다.'))
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final seconds = (row['start_position_ms'] as int) ~/ 1000;
                      return ListTile(
                        leading: const Icon(Icons.play_circle_outline),
                        title: Text(
                          formatPlaybackDate(row['started_at'] as int),
                        ),
                        subtitle: Text(
                          '시작 위치 ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                        ),
                      );
                    },
                  ),
          ),
          if ((more || error != null) && !loading)
            TextButton(
              onPressed: load,
              child: Text(error == null ? '더 보기' : '다시 시도'),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
    ],
  );
}
