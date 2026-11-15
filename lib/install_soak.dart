import 'dart:convert';
import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'native_playback.dart';
import 'playback_diagnostics.dart';

/// Opt-in installed Release diagnostic. Ordinary app launches never call this.
/// Uses the install check's temporary catalog and a caller-supplied test video.
Future<Map<String, Object?>> verifyInstalledPlaybackSoak(
  Player player,
  String reportPath,
) async {
  final seconds = int.parse(
    Platform.environment['SOFT_VAULT_INSTALL_SOAK_SECONDS']!,
  );
  if (seconds < 10 || seconds > 3600) {
    throw ArgumentError('Install soak duration must be 10..3600 seconds');
  }
  final fixture = Platform.environment['SOFT_VAULT_INSTALL_SOAK_FIXTURE'];
  if (fixture == null || !await File(fixture).exists()) {
    throw ArgumentError('Install soak requires a local test video');
  }
  final port = NativePlayback(player);
  await port.openPaused(fixture);
  await player.setPlaylistMode(PlaylistMode.single);
  await player.play();
  final diagnostics = PlaybackDiagnostics(player);
  final errors = <String>[];
  final subscription = player.stream.error.listen(errors.add);
  final samples = <Map<String, Object?>>[];
  final watch = Stopwatch()..start();
  Duration? previous;
  var stalled = 0, loops = 0;
  final result = <String, Object?>{
    'passed': false,
    'requestedSeconds': seconds,
    'fixture': fixture,
    'executable': Platform.resolvedExecutable,
    'samples': samples,
    'errors': errors,
    'scope': 'Installed Release diagnostic video surface; not full library UI',
  };
  Future<void> save() async {
    result['elapsedSeconds'] = watch.elapsedMilliseconds / 1000;
    result['observedLoops'] = loops;
    await File('$reportPath.soak.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
      flush: true,
    );
  }

  try {
    while (watch.elapsed < Duration(seconds: seconds)) {
      await Future<void>.delayed(const Duration(seconds: 10));
      final position = player.state.position;
      if (previous != null && position < previous) loops++;
      stalled = position == previous ? stalled + 1 : 0;
      previous = position;
      samples.add({
        'elapsedSeconds': watch.elapsedMilliseconds / 1000,
        'rssBytes': ProcessInfo.currentRss,
        'positionMs': position.inMilliseconds,
        'durationMs': player.state.duration.inMilliseconds,
        'native': await diagnostics.sample(),
      });
      await save();
      if (stalled >= 2 || errors.isNotEmpty || position <= Duration.zero) {
        throw StateError('Installed playback stalled or reported an error');
      }
    }
    await player.pause();
    await player.setPlaylistMode(PlaylistMode.none);
    await port.seek(const Duration(seconds: 10), exact: true);
    final deadline = Stopwatch()..start();
    while (!await port.settled(const Duration(seconds: 10))) {
      if (deadline.elapsed > const Duration(seconds: 10)) {
        throw StateError('Installed final exact seek did not settle');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    result['finalExactSeekPassed'] = true;
    result['passed'] = true;
    return result;
  } finally {
    await subscription.cancel();
    await save();
  }
}
