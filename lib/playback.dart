/// All operations are queued so a pending open cannot race panic/minimize.
abstract interface class PlaybackPort {
  Future<void> volume(double value);
  Future<void> openPaused(String path, {Duration start = Duration.zero});
  Future<void> play();
  Future<void> minimize();
}

class Playback {
  final PlaybackPort port;
  Future<void> _tail = Future.value();
  Playback(this.port);
  Future<void> _queue(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<void> open(String path, {Duration start = Duration.zero}) =>
      _queue(() async {
        await port.volume(0);
        await port.openPaused(path, start: start);
        await port.volume(0);
        await port.play();
      });
  Future<void> silence() => _queue(() => port.volume(0));
  Future<void> setVolume(double value) =>
      _queue(() => port.volume(value.clamp(0, 100)));
  Future<void> panic() => _queue(() async {
    await port.volume(0);
    await port.minimize();
  });
}
