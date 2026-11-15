import 'dart:async';
import 'package:soft_vault/seek_controller.dart';

class TestSeekPort implements SeekPort {
  @override
  Duration position = const Duration(seconds: 10);
  @override
  Duration duration = const Duration(seconds: 120);
  final commands = <({Duration target, bool exact})>[];
  Completer<void>? commandGate;
  bool canSettle = true, failNext = false;

  @override
  Future<void> seek(Duration target, {required bool exact}) async {
    commands.add((target: target, exact: exact));
    final gate = commandGate;
    commandGate = null;
    if (gate != null) await gate.future;
    if (failNext) {
      failNext = false;
      throw StateError('decoder failure');
    }
    if (canSettle) position = target;
  }

  @override
  Future<bool> settled(Duration target) async => canSettle;
}
