import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/playback.dart';

class Port implements PlaybackPort {
  final events = <String>[];
  bool failVolume = false;
  @override
  Future<void> volume(double value) async {
    events.add('volume:$value');
    if (failVolume) throw StateError('engine unavailable');
  }

  @override
  Future<void> openPaused(String path, {Duration start = Duration.zero}) async {
    events.add('open:$path');
    if (start > Duration.zero) events.add('start:${start.inMilliseconds}');
  }

  @override
  Future<void> play() async {
    events.add('play');
  }

  @override
  Future<void> minimize() async {
    events.add('minimize');
  }
}

void main() {
  test(
    'resume is passed into paused load before play and after silence',
    () async {
      final port = Port();
      await Playback(port).open('resume', start: const Duration(seconds: 12));
      expect(port.events, [
        'volume:0.0',
        'open:resume',
        'start:12000',
        'volume:0.0',
        'play',
      ]);
    },
  );
  test(
    'every open silences before loading and before starting output',
    () async {
      final port = Port();
      final playback = Playback(port);
      await playback.open('a');
      await playback.open('b');
      expect(port.events, [
        'volume:0.0',
        'open:a',
        'volume:0.0',
        'play',
        'volume:0.0',
        'open:b',
        'volume:0.0',
        'play',
      ]);
    },
  );
  test('panic cannot race a pending open', () async {
    final port = Port();
    final playback = Playback(port);
    await Future.wait([playback.open('a'), playback.panic()]);
    expect(port.events.sublist(4), ['volume:0.0', 'minimize']);
  });
  test(
    'failed silence prevents minimize and later requests can recover',
    () async {
      final port = Port()..failVolume = true;
      final playback = Playback(port);
      await expectLater(playback.panic(), throwsStateError);
      expect(port.events, ['volume:0.0']);
      port.failVolume = false;
      await playback.panic();
      expect(port.events.last, 'minimize');
    },
  );
}
