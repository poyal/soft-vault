import 'library.dart';

extension PlaybackHistory on Library {
  Future<void> recordPlayback(
    int mediaId,
    DateTime startedAt,
    Duration start,
  ) => db.transaction((tx) async {
    final changed = await tx.rawUpdate(
      'UPDATE media SET play_count=play_count+1, last_played=? WHERE id=?',
      [startedAt.millisecondsSinceEpoch, mediaId],
    );
    if (changed != 1) throw StateError('재생 기록을 저장할 영상을 찾지 못했습니다.');
  });
}

/// A new open is one session; pause, resume and seek keep the same session.
/// Wait for real playback progress so a failed open or preview is not counted.
class PlaybackSession {
  final Future<void> Function() record;
  Future<void>? pending;
  PlaybackSession(this.record);

  Future<void> observe(
    Duration position,
    Duration duration,
    bool playing,
  ) async {
    if (!playing || position <= Duration.zero || duration <= Duration.zero)
      return;
    if (pending != null) return pending;
    final work = record();
    pending = work;
    try {
      await work;
    } catch (_) {
      pending = null;
      rethrow;
    }
  }
}

String formatPlaybackDate(int milliseconds) {
  if (milliseconds <= 0) return '기록 없음';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}
