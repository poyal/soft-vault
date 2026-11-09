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
    await tx.insert('playback_history', {
      'media_id': mediaId,
      'started_at': startedAt.millisecondsSinceEpoch,
      'start_position_ms': start.inMilliseconds.clamp(0, 1 << 50),
    });
  });

  Future<List<Map<String, Object?>>> playbackHistory(
    int mediaId, {
    int offset = 0,
    int limit = 50,
  }) => db.query(
    'playback_history',
    where: 'media_id=?',
    whereArgs: [mediaId],
    orderBy: 'started_at DESC, id DESC',
    offset: offset,
    limit: limit,
  );
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
