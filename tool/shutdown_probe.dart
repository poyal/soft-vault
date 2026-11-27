// Isolated process probe. Never opens the user's catalog.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/library.dart';

Future<void> main(List<String> args) async {
  // Finder and session restoration can launch the probe without a test run.
  if (Platform.isMacOS && args.isEmpty) exit(0);
  if (args.length != 4 ||
      ![
        'normal',
        'repeated',
        if (Platform.isMacOS) ...['application', 'repeated-application'],
      ].contains(args[2]) ||
      ![
        'idle',
        'playing',
        'paused',
        'seeking',
        'extracting',
      ].contains(args[3])) {
    stderr.writeln(
      'Expected scratch-directory, video, normal|repeated or '
      'application|repeated-application (macOS), '
      'and idle|playing|paused|seeking|extracting.',
    );
    exit(64);
  }
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  final root = Directory(args[0]);
  await root.create(recursive: true);
  final trace = File('${root.path}/trace.jsonl').openSync(mode: FileMode.write);
  void mark(String phase) => trace.writeStringSync(
    '${jsonEncode({'phase': phase, 'us': DateTime.now().microsecondsSinceEpoch})}\n',
  );
  final lib = await Library.open('${root.path}/catalog.sqlite');
  await lib.setting('welcome_seen', true);
  final fixture = args[1], mode = args[2], playing = args[3] != 'idle';
  final id = await lib.db.insert('media', {
    'path': fixture,
    'folder': root.path,
    'title': 'shutdown fixture',
    'type': 'video',
    'added': 1,
    'duration': 52,
  });
  final key = GlobalKey();
  void writeExpected(String filename) {
    final dynamic home = key.currentState;
    File('${root.path}/$filename').writeAsStringSync(
      jsonEncode({
        'positionMs': home.seeks.resumePosition.inMilliseconds,
        'durationMs': home.player.state.duration.inMilliseconds,
      }),
    );
  }

  final quitApplication =
      mode == 'application' || mode == 'repeated-application';
  if (quitApplication) {
    // AppKit delivers termination asynchronously. A pending seek can settle
    // between the request and Flutter receiving it. Observe that boundary
    // before VaultHome registers its own application exit listener.
    var repeatSent = false;
    AppLifecycleListener(
      onExitRequested: () async {
        mark('application_exit_requested');
        if (mode == 'repeated-application' && !repeatSent) {
          // Deliver the next Quit while the first decision is still pending.
          repeatSent = true;
          mark('repeat_quit_requested');
          unawaited(windowManager.destroy());
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        writeExpected('expected-at-handler.json');
        return AppExitResponse.exit;
      },
    );
  }
  runApp(
    MaterialApp(
      home: VaultHome(key: key, library: lib, onCloseStage: mark),
    ),
  );
  Timer(const Duration(seconds: 2), () async {
    try {
      final dynamic home = key.currentState;
      await home.scanFuture;
      if (playing) {
        home.playbackMediaId = id;
        await home.player.setVolume(0.0);
        await home.player.open(Media(fixture));
        home.update(() {
          home.playingView = true;
        });
        await Future<void>.delayed(const Duration(seconds: 2));
        if (args[3] == 'paused') await home.player.pause();
      }
      if (args[3] == 'seeking') {
        for (var i = 0; i < 10; i++) {
          home.seeks.relative(Duration(seconds: i.isEven ? 5 : -1));
          unawaited(home.seeks.finish() as Future<void>);
          if (i < 9)
            await Future<void>.delayed(const Duration(milliseconds: 80));
        }
      }
      if (args[3] == 'extracting') {
        // Exercise the same cancellable FFmpeg child and shutdown join as
        // enrichment, without changing thumbnails in the user's catalog.
        home.enrichmentCancelled = true;
        await home.enrichmentFuture;
        home.enrichmentCancelled = false;
        home.enrichmentFuture =
            (home.mediaTools.run('ffmpeg', <String>[
                      '-nostdin',
                      '-v',
                      'error',
                      '-re',
                      '-i',
                      fixture,
                      '-vf',
                      'fps=1,scale=480:-2',
                      '-frames:v',
                      '8',
                      '-f',
                      'null',
                      '-',
                    ], cancelled: () => home.enrichmentCancelled as bool)
                    as Future)
                .then<void>((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      writeExpected('expected.json');
      mark('close_requested');
      if (quitApplication) {
        unawaited(windowManager.destroy());
      } else {
        home.onWindowClose();
      }
      if (mode == 'repeated') {
        home.onWindowClose();
        home.onWindowClose();
      }
    } catch (e) {
      mark('error:${e.runtimeType}');
      exit(2);
    }
  });
}
