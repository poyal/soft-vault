import 'dart:convert';
import 'package:media_kit/media_kit.dart';

/// Opt-in native samples for profile/installation checks. No timer or sampling
/// overhead is added to ordinary playback. Missing backend counters stay null.
class PlaybackDiagnostics {
  final Player player;
  PlaybackDiagnostics(this.player);
  Future<Map<String, Object?>> sample() async {
    final native = player.platform as NativePlayer;
    final result = <String, Object?>{};
    for (final name in [
      'mpv-version',
      'cache-on-disk',
      'demuxer-max-bytes',
      'demuxer-max-back-bytes',
      'hr-seek-framedrop',
      'video-sync',
      'hwdec-current',
      'video-codec',
      'container-fps',
      'video-params/w',
      'video-params/h',
      'video-pts',
      'playback-time',
      'seeking',
      'paused-for-cache',
      'frame-drop-count',
      'decoder-frame-drop-count',
      'mistimed-frame-count',
      'vo-delayed-frame-count',
      'avsync',
      'demuxer-cache-duration',
      'demuxer-cache-state',
    ]) {
      final raw = await native.getProperty(name);
      if (raw.isEmpty) {
        result[name] = null;
      } else {
        try {
          result[name] = jsonDecode(raw);
        } on FormatException {
          result[name] = raw;
        }
      }
    }
    return result;
  }
}
