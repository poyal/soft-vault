import 'native_surface.dart';
import 'settings_navigation.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';
import 'package:soft_vault/main.dart';
import 'package:soft_vault/media_tools.dart';
import 'package:soft_vault/file_list.dart';
import 'package:soft_vault/player_controls.dart';
import 'package:window_manager/window_manager.dart';

/// Only the OS chooser is substituted. UI, SQLite, filesystem and decoder are real.
class ScenarioPicker extends FileSelectorPlatform {
  String? openPath, savePath, directoryPath;
  int opened = 0, saved = 0;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    opened++;
    return openPath == null ? null : XFile(openPath!);
  }

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    saved++;
    return savePath == null ? null : FileSaveLocation(savePath!);
  }

  @override
  Future<String?> getDirectoryPathWithOptions(
    FileDialogOptions options,
  ) async => directoryPath;
}

class ScenarioApp {
  final WidgetTester tester;
  final Directory root, source, target;
  final Library library;
  final picker = ScenarioPicker();
  final FileSelectorPlatform previousPicker;
  ScenarioApp._(
    this.tester,
    this.root,
    this.source,
    this.target,
    this.library,
    this.previousPicker,
  );
  static Future<ScenarioApp> create(
    WidgetTester tester, {
    int fixtures = 2,
    int videos = 0,
  }) async {
    MediaKit.ensureInitialized();
    await windowManager.ensureInitialized();
    final root = await Directory(
      await Directory.systemTemp.resolveSymbolicLinks(),
    ).createTemp('vault-ui-scenario-');
    final source = await Directory(p.join(root.path, '원본')).create();
    final target = await Directory(p.join(root.path, '정리')).create();
    const fixture = String.fromEnvironment('VIDEO_FIXTURE');
    for (var i = 0; i < fixtures; i++) {
      await File(fixture).copy(p.join(source.path, 'fixture-$i.mp4'));
    }
    for (var i = 0; i < videos; i++) {
      await File(fixture).copy(p.join(source.path, 'video-$i.mp4'));
    }
    final library = await Library.open(p.join(root.path, 'db.sqlite'));
    await library.connect(source.path);
    await library.connect(target.path);
    await MediaTools(
      library,
      Directory(p.join(root.path, 'thumbnails')),
      MediaTools.bundledBin(),
    ).enrich();
    final app = ScenarioApp._(
      tester,
      root,
      source,
      target,
      library,
      FileSelectorPlatform.instance,
    );
    FileSelectorPlatform.instance = app.picker;
    return app;
  }

  Future<void> mount() async {
    await windowManager.setTitle(
      'Soft Vault · E2E - ${tester.testDescription}',
    );
    await setNativeFullscreen(false);
    await windowManager.restore();
    await resizeNativeSurface(tester, const Size(1280, 800));
    await tester.pumpWidget(VaultApp(library: library));
    await settle(15);
  }

  Future<void> settle([int ticks = 5]) async {
    for (var i = 0; i < ticks; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expectNativeSurface(tester);
  }

  Future<void> until(bool Function() condition, {int ticks = 150}) async {
    for (var i = 0; i < ticks && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(condition(), isTrue);
    expect(tester.takeException(), isNull);
    expectNativeSurface(tester);
  }

  Future<void> menu(String label) async {
    await settingsAction(tester, label);
    await settle();
  }

  Future<void> tap(String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.tap(find.text(label).last);
    await settle();
  }

  Future<void> key(LogicalKeyboardKey value) async {
    // KeyEventSimulator's automatic lookup uses debug-only key names.
    final physical = {
      LogicalKeyboardKey.space: PhysicalKeyboardKey.space,
      LogicalKeyboardKey.keyF: PhysicalKeyboardKey.keyF,
      LogicalKeyboardKey.escape: PhysicalKeyboardKey.escape,
    };
    await tester.sendKeyEvent(value, physicalKey: physical[value]);
    if (value == LogicalKeyboardKey.escape) {
      await waitNativeMinimized(tester);
    } else {
      await settle();
    }
  }

  Future<void> enterText(Finder field, String text) async {
    if (kProfileMode) {
      // TestTextInput uses client ID -1, which the engine accepts only in debug.
      // Feed the actual text-input client in profile mode; onChanged, querying,
      // layout and paint still follow the normal application path.
      await tester.tap(field);
      final editable = tester.state<EditableTextState>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      editable.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
      await tester.pump();
    } else {
      await tester.enterText(field, text);
    }
  }

  Future<Map<String, Object?>> row(String title) async =>
      (await library.items()).firstWhere((r) => r['title'] == title);
  List<Map<String, Object?>> get visible =>
      tester.widget<VaultFileList>(find.byType(VaultFileList)).items;
  Player get player =>
      tester.widget<PlaybackControls>(find.byType(PlaybackControls)).player;
  Future<void> close() async {
    FileSelectorPlatform.instance = previousPicker;
    await setNativeFullscreen(false);
    await windowManager.restore();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await library.close();
    await root.delete(recursive: true);
  }
}
