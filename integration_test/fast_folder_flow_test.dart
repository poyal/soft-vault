import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/main.dart';
import 'package:window_manager/window_manager.dart';
import 'support/native_surface.dart';
import 'support/scenario_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'folder shows all 174 files before thumbnails finish and can stop them',
    (tester) async {
      MediaKit.ensureInitialized();
      await windowManager.ensureInitialized();
      await prepareNativeSurface(tester);
      final root = await Directory.systemTemp.createTemp('vault-fast-ui-');
      final folder = await Directory(p.join(root.path, 'videos')).create();
      final library = await Library.open(p.join(root.path, 'vault.sqlite'));
      final previousPicker = FileSelectorPlatform.instance;
      final captureKey = GlobalKey();
      dynamic home;
      try {
        // Bad media must not hold up discovery either. Only one real fixture is
        // needed; the remaining probes make the background work observable.
        for (var i = 0; i < 173; i++) {
          await File(
            p.join(folder.path, 'sample-$i.mp4'),
          ).writeAsBytes([1, 2, 3]);
        }
        await File(
          const String.fromEnvironment('VIDEO_FIXTURE'),
        ).copy(p.join(folder.path, 'real.mp4'));
        await library.setting('welcome_seen', true);
        FileSelectorPlatform.instance = ScenarioPicker()
          ..directoryPath = folder.path;
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: VaultApp(library: library),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        home = tester.state(find.byType(VaultHome)) as dynamic;
        final watch = Stopwatch()..start();
        final connecting = home.connect() as Future<void>;
        for (
          var i = 0;
          i < 150 && (home.items.length != 174 || home.busy);
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await connecting;
        watch.stop();
        await tester.pump();
        expect(home.items, hasLength(174));
        expect(home.busy, isFalse);
        expect(
          tester.widget<VaultFileList>(find.byType(VaultFileList)).items,
          hasLength(174),
        );
        expect(
          (await library.items()).every((row) => row['fingerprint'] == ''),
          isTrue,
        );
        expect(home.enrichmentFuture, isNotNull);
        expect(find.text('중지'), findsOneWidget);
        final artifacts = await Directory('build/e2e').create(recursive: true);
        final boundary =
            captureKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          p.join(artifacts.path, 'fast-folder.png'),
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        await File(
          p.join(artifacts.path, 'fast-folder-time.txt'),
        ).writeAsString(
          '174 files visible in ${watch.elapsedMilliseconds} ms; thumbnail worker still active',
        );
        await tester.tap(find.text('중지'));
        for (var i = 0; i < 40 && home.enrichmentFuture != null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(home.enrichmentFuture, isNull);
        expect(home.items, hasLength(174));
        expect(find.text('계속'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        if (home != null) {
          home.enrichmentCancelled = true;
          await home.enrichmentFuture;
          await home.scanFuture;
        }
        FileSelectorPlatform.instance = previousPicker;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await library.close();
        await root.delete(recursive: true);
      }
    },
  );
}
