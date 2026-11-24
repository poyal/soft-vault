import 'dart:async';
import 'package:flutter/foundation.dart';

abstract interface class SeekPort {
  Duration get position;
  Duration get duration;
  Future<void> seek(Duration position, {required bool exact});
  Future<bool> settled(Duration position);
}

/// One native command at a time, with just one replaceable pending destination.
/// Displayed intent is independent of delayed position events from the decoder.
class SeekController extends ChangeNotifier {
  final SeekPort port;
  final void Function(Object error) onError;
  final Duration previewInterval, settleTimeout;
  SeekController(
    this.port, {
    required this.onError,
    this.previewInterval = const Duration(milliseconds: 150),
    this.settleTimeout = const Duration(seconds: 10),
  });

  Duration? _target, _settledTarget;
  Duration _undo = Duration.zero;
  Duration _confirmed = Duration.zero;
  Timer? _previewTimer, _finishTimer;
  _SeekRequest? _pending, _sending;
  Future<void>? _worker;
  int _generation = 0;
  bool _dragging = false, _keys = false, _disposed = false;
  bool _enabled = true;
  bool _previewExact = false;

  Duration get displayPosition => _target ?? port.position;
  bool get busy => _target != null;
  bool get enabled => _enabled && !_disposed;
  bool get dragging => _dragging;
  bool get keyboardActive => _keys;
  Duration get undoPosition => _undo;
  Duration get resumePosition => busy ? _confirmed : port.position;

  Duration _clamp(Duration value) => Duration(
    microseconds: value.inMicroseconds.clamp(0, port.duration.inMicroseconds),
  );

  void _begin() {
    if (!busy) {
      _confirmed = _undo = port.position;
      // Playback may have advanced since the last gesture completed.
      _settledTarget = null;
    }
  }

  void beginDrag() {
    if (!enabled || port.duration <= Duration.zero) return;
    _begin();
    _keys = false;
    _finishTimer?.cancel();
    _dragging = true;
    _target ??= port.position;
    notifyListeners();
  }

  void preview(Duration target) {
    if (!enabled || port.duration <= Duration.zero) return;
    if (!_dragging) beginDrag();
    _target = _clamp(target);
    notifyListeners();
    _schedulePreview();
  }

  void _schedulePreview({bool exact = false}) {
    _previewExact = exact;
    _previewTimer ??= Timer(previewInterval, () {
      _previewTimer = null;
      if (_target != null) _submit(_target!, exact: _previewExact);
    });
  }

  Future<void> seekTo(Duration target) {
    if (!enabled || port.duration <= Duration.zero) return Future.value();
    _begin();
    _dragging = _keys = false;
    _previewTimer?.cancel();
    _previewTimer = null;
    _finishTimer?.cancel();
    _target = _clamp(target);
    notifyListeners();
    return _submit(_target!, exact: true);
  }

  void relative(Duration delta, {bool repeat = false, bool precise = false}) {
    if (!enabled || port.duration <= Duration.zero) return;
    _begin();
    _dragging = false;
    _keys = true;
    _target = _clamp(displayPosition + delta);
    notifyListeners();
    if (repeat) {
      _schedulePreview(exact: precise);
    } else {
      _previewTimer?.cancel();
      _previewTimer = null;
      _submit(_target!, exact: true);
    }
    _finishTimer?.cancel();
    _finishTimer = Timer(previewInterval, finish);
  }

  Future<void> finish() {
    _dragging = _keys = false;
    _previewTimer?.cancel();
    _previewTimer = null;
    _finishTimer?.cancel();
    final target = _target;
    if (_disposed || target == null) return _worker ?? Future.value();
    if (_settledTarget == target && _pending == null && _sending == null) {
      _target = null;
      notifyListeners();
      return Future.value();
    }
    if ((_pending?.exact == true && _pending?.target == target) ||
        (_pending == null &&
            _sending?.exact == true &&
            _sending?.target == target)) {
      return _worker ?? Future.value();
    }
    return _submit(target, exact: true);
  }

  Future<void> undo() {
    final destination = _undo;
    final previous = displayPosition;
    final result = seekTo(destination);
    _undo = previous;
    return result;
  }

  Future<void> _submit(Duration target, {required bool exact}) {
    final sending = _sending;
    if (exact &&
        sending != null &&
        sending.exact &&
        sending.generation == _generation &&
        sending.target == target) {
      // The user returned to the in-flight destination. Drop the intervening
      // request and let the existing exact decode finish.
      _pending = null;
      return _worker ?? Future.value();
    }
    _pending = _SeekRequest(target, exact, _generation);
    return _worker ??= _run();
  }

  Future<void> _run() async {
    try {
      while (!_disposed && _pending != null) {
        final request = _pending!;
        _pending = null;
        _sending = request;
        try {
          _settledTarget = null;
          await port.seek(request.target, exact: request.exact);
          if (request.generation != _generation) continue;
          if (!request.exact) continue;
          var expired = false;
          final deadline = Timer(settleTimeout, () => expired = true);
          try {
            while (!_disposed &&
                request.generation == _generation &&
                _pending == null) {
              final settled = await port.settled(request.target);
              if (request.generation != _generation || _pending != null) break;
              if (settled) {
                _confirmed = request.target;
                _settledTarget = request.target;
                if (!_dragging && !_keys && _target == request.target) {
                  _target = null;
                  notifyListeners();
                }
                break;
              }
              if (expired) {
                throw TimeoutException('영상 탐색이 완료되지 않았습니다.', settleTimeout);
              }
              await Future<void>.delayed(const Duration(milliseconds: 16));
            }
          } finally {
            deadline.cancel();
          }
        } catch (error) {
          if (!_disposed &&
              request.generation == _generation &&
              _pending == null) {
            _target = null;
            _dragging = _keys = false;
            _previewTimer?.cancel();
            _previewTimer = null;
            _finishTimer?.cancel();
            onError(error);
            notifyListeners();
          }
        } finally {
          _sending = null;
        }
      }
    } finally {
      _worker = null;
    }
  }

  /// Await this before opening/stopping a file: an already submitted native
  /// command must finish before the new media receives any commands.
  Future<void> cancel() {
    _generation++;
    _previewTimer?.cancel();
    _previewTimer = null;
    _finishTimer?.cancel();
    _pending = null;
    _target = _settledTarget = null;
    _undo = Duration.zero;
    _dragging = _keys = false;
    if (!_disposed) notifyListeners();
    return _worker ?? Future.value();
  }

  Future<void> suspend() {
    _enabled = false;
    return cancel();
  }

  void resume() {
    if (_disposed) return;
    _enabled = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}

class _SeekRequest {
  final Duration target;
  final bool exact;
  final int generation;
  const _SeekRequest(this.target, this.exact, this.generation);
}
