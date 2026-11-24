import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/player_controls.dart';
import 'package:soft_vault/seek_controller.dart';
import 'support/seek_port.dart';

void main() {
  late TestSeekPort port;
  late SeekController seeks;
  late List<Object> errors;
  setUp(() {
    port = TestSeekPort();
    errors = [];
    seeks = SeekController(
      port,
      onError: errors.add,
      settleTimeout: const Duration(milliseconds: 100),
    );
  });
  tearDown(() => seeks.dispose());

  testWidgets(
    'clicking the same timestamp again rewinds after playback advances',
    (tester) async {
      await seeks.seekTo(const Duration(seconds: 20));
      port.position = const Duration(seconds: 27);
      seeks.beginDrag();
      seeks.preview(const Duration(seconds: 20));
      await seeks.finish();
      expect(port.position, const Duration(seconds: 20));
      expect(port.commands, hasLength(2));
    },
  );

  testWidgets('returning to an in-flight exact target reuses its decode', (
    tester,
  ) async {
    final gate = port.commandGate = Completer<void>();
    final seeking = seeks.seekTo(const Duration(seconds: 35));
    seeks.seekTo(const Duration(seconds: 40));
    seeks.seekTo(const Duration(seconds: 35));
    gate.complete();
    await seeking;
    expect(port.commands, [(target: const Duration(seconds: 35), exact: true)]);
    expect(seeks.busy, isFalse);
  });

  testWidgets('rapid key releases keep only the newest queued exact seek', (
    tester,
  ) async {
    final gate = port.commandGate = Completer<void>();
    for (var i = 0; i < 10; i++) {
      seeks.relative(const Duration(seconds: 5));
      unawaited(seeks.finish());
      await tester.pump(const Duration(milliseconds: 8));
    }
    expect(seeks.resumePosition, const Duration(seconds: 10));
    gate.complete();
    await tester.pump();
    expect(port.commands.first, (
      target: const Duration(seconds: 15),
      exact: true,
    ));
    expect(port.commands.last, (
      target: const Duration(seconds: 60),
      exact: true,
    ));
    expect(port.commands.where((command) => command.exact), hasLength(2));
    expect(port.commands, hasLength(2));
    expect(seeks.busy, isFalse);
  });

  testWidgets(
    'a second slider click preserves the confirmed position until it settles',
    (tester) async {
      await seeks.seekTo(const Duration(seconds: 20));
      final gate = port.commandGate = Completer<void>();
      seeks.beginDrag();
      seeks.preview(const Duration(seconds: 90));
      unawaited(seeks.finish());
      expect(seeks.resumePosition.inSeconds, 20);
      gate.complete();
      await tester.pump();
      expect(port.commands.last, (
        target: const Duration(seconds: 90),
        exact: true,
      ));
      expect(port.commands.where((command) => command.exact), hasLength(2));
      expect(seeks.resumePosition.inSeconds, 90);
    },
  );

  testWidgets(
    'opening another file suspends input until the new media is ready',
    (tester) async {
      final gate = port.commandGate = Completer<void>();
      seeks.seekTo(const Duration(seconds: 80));
      final waiting = seeks.suspend();
      seeks.preview(const Duration(seconds: 90));
      seeks.relative(const Duration(seconds: 5));
      await seeks.seekTo(const Duration(seconds: 100));
      expect(port.commands.length, 1);
      gate.complete();
      await tester.pump();
      await waiting;
      port.position = Duration.zero;
      seeks.resume();
      await seeks.seekTo(const Duration(seconds: 5));
      expect(port.commands.last.target.inSeconds, 5);
      expect(seeks.busy, isFalse);
    },
  );

  testWidgets(
    'drag changes intent immediately, limits previews and commits once',
    (tester) async {
      seeks.beginDrag();
      for (var i = 20; i <= 80; i++) {
        seeks.preview(Duration(seconds: i));
      }
      expect(seeks.displayPosition.inSeconds, 80);
      expect(port.commands, isEmpty);
      await tester.pump(const Duration(milliseconds: 150));
      expect(port.commands.single, (
        target: const Duration(seconds: 80),
        exact: false,
      ));
      seeks.preview(const Duration(seconds: 90));
      final done = seeks.finish();
      await tester.pump();
      await done;
      await tester.pump(const Duration(seconds: 1));
      expect(port.commands.length, 2);
      expect(port.commands.last, (
        target: const Duration(seconds: 90),
        exact: true,
      ));
      expect(seeks.busy, isFalse);
      expect(seeks.undoPosition.inSeconds, 10);
    },
  );

  testWidgets('slow native commands keep only the newest pending destination', (
    tester,
  ) async {
    final gate = port.commandGate = Completer<void>();
    seeks.seekTo(const Duration(seconds: 20));
    seeks.seekTo(const Duration(seconds: 40));
    seeks.seekTo(const Duration(seconds: 80));
    expect(port.commands.length, 1);
    gate.complete();
    await tester.pump();
    expect(port.commands.map((c) => c.target.inSeconds), [20, 80]);
    expect(seeks.busy, isFalse);
  });

  testWidgets(
    'repeated keys accumulate from intent despite stale decoder positions',
    (tester) async {
      port.canSettle = false;
      seeks.relative(const Duration(seconds: 5));
      for (var i = 0; i < 9; i++) {
        seeks.relative(const Duration(seconds: 5), repeat: true);
      }
      seeks.relative(const Duration(seconds: -5), repeat: true);
      expect(seeks.displayPosition.inSeconds, 55);
      expect(port.position.inSeconds, 10);
      port.canSettle = true;
      seeks.finish();
      await tester.pump(const Duration(milliseconds: 20));
      expect(port.commands.last.target.inSeconds, 55);
      expect(seeks.undoPosition.inSeconds, 10);
      expect(seeks.busy, isFalse);
    },
  );

  testWidgets(
    'precise key repeats are coalesced without using keyframe seeks',
    (tester) async {
      seeks.relative(const Duration(seconds: 1), precise: true);
      for (var i = 0; i < 9; i++) {
        seeks.relative(const Duration(seconds: 1), repeat: true, precise: true);
      }
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 20));
      expect(port.commands.length, lessThanOrEqualTo(3));
      expect(port.commands.every((command) => command.exact), isTrue);
      expect(port.commands.last.target.inSeconds, 20);
      expect(seeks.busy, isFalse);
    },
  );

  testWidgets(
    'cancel drains submitted command and discards old file requests',
    (tester) async {
      final gate = port.commandGate = Completer<void>();
      seeks.seekTo(const Duration(seconds: 20));
      seeks.seekTo(const Duration(seconds: 90));
      var drained = false;
      final cancelling = seeks.cancel().then((_) => drained = true);
      await tester.pump();
      expect(drained, isFalse);
      gate.complete();
      await tester.pump();
      await cancelling;
      expect(port.commands.length, 1);
      expect(seeks.busy, isFalse);
      await seeks.seekTo(const Duration(seconds: 30));
      expect(port.commands.last.target.inSeconds, 30);
      expect(errors, isEmpty);
    },
  );

  testWidgets('timeout and decoder failure clear intent and permit recovery', (
    tester,
  ) async {
    port.canSettle = false;
    seeks.seekTo(const Duration(seconds: 70));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(errors.single, isA<TimeoutException>());
    expect(seeks.busy, isFalse);
    port.canSettle = true;
    port.failNext = true;
    await seeks.seekTo(const Duration(seconds: 30));
    expect(errors.last, isA<StateError>());
    await seeks.seekTo(const Duration(seconds: 40));
    expect(port.position.inSeconds, 40);
    expect(seeks.busy, isFalse);
  });

  testWidgets('clamps boundaries, ignores unknown duration, and toggles undo', (
    tester,
  ) async {
    await seeks.seekTo(const Duration(seconds: 300));
    expect(port.position, port.duration);
    await seeks.undo();
    expect(port.position.inSeconds, 10);
    await seeks.undo();
    expect(port.position, port.duration);
    await seeks.seekTo(const Duration(seconds: -10));
    expect(port.position, Duration.zero);
    final count = port.commands.length;
    port.duration = Duration.zero;
    seeks.preview(const Duration(seconds: 10));
    await seeks.seekTo(const Duration(seconds: 10));
    expect(port.commands.length, count);
  });

  testWidgets(
    'native settling is superseded without waiting for obsolete target',
    (tester) async {
      port.canSettle = false;
      seeks.seekTo(const Duration(seconds: 20));
      await tester.pump();
      port.canSettle = true;
      seeks.seekTo(const Duration(seconds: 60));
      await tester.pump(const Duration(milliseconds: 20));
      expect(port.commands.last.target.inSeconds, 60);
      expect(seeks.busy, isFalse);
      expect(errors, isEmpty);
    },
  );

  testWidgets(
    'timeline ignores stale positions during drag and updates duration while paused',
    (tester) async {
      final positions = StreamController<Duration>.broadcast(sync: true);
      final durations = StreamController<Duration>.broadcast(sync: true);
      addTearDown(positions.close);
      addTearDown(durations.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaybackSeekBar(
              seeks: seeks,
              positions: positions.stream,
              durations: durations.stream,
            ),
          ),
        ),
      );
      seeks.beginDrag();
      seeks.preview(const Duration(seconds: 70));
      positions.add(const Duration(seconds: 11));
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 70000);
      port.duration = const Duration(seconds: 200);
      durations.add(port.duration);
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).max, 200000);
      await seeks.finish();
      positions.add(port.position);
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 70000);
    },
  );
}
