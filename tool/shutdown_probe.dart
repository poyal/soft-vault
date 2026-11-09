// Isolated process probe. Never opens the user's catalog.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/library.dart';

Future<void> main(List<String> args) async {
  if (args.length != 4 ||
      !['normal', 'repeated'].contains(args[2]) ||
      !['idle', 'playing', 'paused'].contains(args[3])) {
    throw ArgumentError(
      'Expected: scratch-directory video normal|repeated idle|playing|paused',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  final root = Directory(args[0]);
  await root.create(recursive: true);
  final trace = File('${root.path}/trace.jsonl');
  void mark(String phase) => trace.writeAsStringSync(
    '${jsonEncode({'phase': phase, 'us': DateTime.now().microsecondsSinceEpoch})}\n',
    mode: FileMode.append,
    flush: true,
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
  runApp(
    MaterialApp(
      home: VaultHome(key: key, library: lib),
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
      await File('${root.path}/expected.json').writeAsString(
        jsonEncode({
          'positionMs': home.player.state.position.inMilliseconds,
          'durationMs': home.player.state.duration.inMilliseconds,
        }),
      );
      mark('close_requested');
      home.onWindowClose();
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
