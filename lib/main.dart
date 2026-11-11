import 'settings_components.dart';
import 'library_filter.dart';
import 'library_filter_dialog.dart';
import 'design.dart';
import 'app_updater.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'library.dart';
import 'playback.dart';
import 'deck.dart';
import 'catalog_panels.dart';
import 'settings_panel.dart';
import 'key_bindings.dart';
import 'file_jobs.dart';
import 'file_dialogs.dart';
import 'media_tools.dart';
import 'file_list.dart';
import 'player_controls.dart';
import 'detail_dialog.dart';
import 'native_playback.dart';
import 'install_check.dart';
import 'search_dialog.dart';
import 'advanced_catalog.dart';
import 'criteria_dialog.dart';
import 'organize_panel.dart';
import 'rule_runner.dart';
import 'scenes_dialog.dart';
import 'thumbnail_dialog.dart';
import 'nfo_service.dart';
import 'welcome_dialog.dart';
import 'privacy_lock.dart';
import 'privacy_ui.dart';
import 'window_lifecycle.dart';
import 'metadata_exchange_dialog.dart';
import 'playback_history.dart';
import 'playback_history_dialog.dart';
export 'native_playback.dart';
part 'home_features.dart';
part 'extended_features.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  if (arguments.length >= 3 && arguments.first == '--verify-install') {
    await verifyInstalledApp(
      arguments[1],
      arguments[2],
      arguments.length > 3 ? arguments[3] : null,
    );
    return;
  }
  await windowManager.setMinimumSize(const Size(1000, 700));
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final updateRoot = Directory(p.join(directory.path, 'updates'));
  final healthRun =
      arguments.length == 2 && arguments.first == '--update-ready';
  final journal = File(p.join(updateRoot.path, 'transaction.json'));
  if (!healthRun && await journal.exists()) {
    final transaction = jsonDecode(await journal.readAsString());
    if (!['complete', 'rolledBack'].contains(transaction['state'])) {
      final helper = p.join(
        updateRoot.path,
        Platform.isWindows ? 'soft_vault_updater.exe' : 'soft_vault_updater',
      );
      final config = jsonDecode(
        await rootBundle.loadString('assets/update-config.json'),
      );
      await Process.start(helper, [
        updateRoot.path,
        transaction['target'],
        directory.path,
        '$pid',
        config['publicKey'],
        '--recover',
      ], mode: ProcessStartMode.detached);
      exit(0);
    }
  }
  if (healthRun) {
    final expected = p.join(updateRoot.path, 'healthy');
    if (p.normalize(arguments[1]) != p.normalize(expected))
      throw StateError('Invalid health path');
    final checkLibrary = await Library.open(
      p.join(directory.path, 'vault.sqlite'),
    );
    await checkLibrary.close();
    final checkPrivacy = PrivacyLock(p.join(directory.path, 'privacy.sqlite'));
    await checkPrivacy.status();
    await checkPrivacy.close();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await File(expected).writeAsString('ready', flush: true);
    });
  }
  AppUpdater.instance = AppUpdater(updateRoot);
  try {
    await AppUpdater.instance!.initialize();
  } catch (_) {
    // Optional update storage must not prevent opening a local library.
    AppUpdater.instance = null;
  }
  Future<Library>? library;
  runApp(
    VaultApp(
      privacy: PrivacyLock(p.join(directory.path, 'privacy.sqlite')),
      loadLibrary: () =>
          library ??= Library.open(p.join(directory.path, 'vault.sqlite')),
    ),
  );
}

class VaultApp extends StatelessWidget {
  final Library? library;
  final PrivacyLock? privacy;
  final Future<Library> Function()? loadLibrary;
  const VaultApp({super.key, this.library, this.privacy, this.loadLibrary})
    : assert(library != null || loadLibrary != null);
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Soft Vault',
    // Escape belongs to panic/minimize, including while a dialog has focus.
    builder: (context, child) => Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape):
            DoNothingAndStopPropagationIntent(),
      },
      child: SettingsTheme(child: child!),
    ),
    theme: ThemeData(
      fontFamily: DeckDesign.font,
      fontFamilyFallback: const ['Malgun Gothic', 'Apple SD Gothic Neo'],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashFactory: NoSplash.splashFactory,
      dialogTheme: DialogThemeData(
        backgroundColor: DeckDesign.sidebar,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: DeckDesign.line),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: DeckDesign.text,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: DeckDesign.text,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: DeckDesign.accent,
        selectionColor: Color(0x6687b8d8),
      ),
      tooltipTheme: const TooltipThemeData(
        textStyle: TextStyle(fontSize: 14, color: DeckDesign.background),
      ),
      dividerColor: DeckDesign.line,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          fontSize: 16,
          color: DeckDesign.text,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(fontSize: 14, letterSpacing: 0),
        labelLarge: TextStyle(fontSize: 15, letterSpacing: 0),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff13212b),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xff334c60)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xff334c60)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: DeckDesign.accent, width: 1.5),
        ),
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DeckDesign.background,
      colorScheme: const ColorScheme.dark(
        primary: DeckDesign.accent,
        secondary: DeckDesign.accent,
        secondaryContainer: Color(0xff233b4e),
        onSecondaryContainer: Color(0xffe3eaf1),
        surface: DeckDesign.sidebar,
        onSurface: DeckDesign.text,
      ),
      useMaterial3: true,
      chipTheme: const ChipThemeData(
        selectedColor: Color(0xff233b4e),
        side: BorderSide(color: DeckDesign.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xff3b5366)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    ),
    home: privacy == null
        ? VaultHome(library: library!)
        : PrivacyGate(
            privacy: privacy!,
            openHome: (lockNow) async => VaultHome(
              library: library ?? await loadLibrary!(),
              privacy: privacy,
              lockNow: lockNow,
            ),
          ),
  );
}

class VaultHome extends StatefulWidget {
  final Library library;
  final PrivacyLock? privacy;
  final VoidCallback? lockNow;
  const VaultHome({
    super.key,
    required this.library,
    this.privacy,
    this.lockNow,
  });
  @override
  State<VaultHome> createState() => _VaultHomeState();
}

class _VaultHomeState extends State<VaultHome> with WindowListener {
  final player = Player();
  late final VideoController video;
  late final playback = Playback(NativePlayback(player));
  late final keys = KeyBindings(widget.library);
  late final jobs = FileJobs(widget.library);
  late final rules = RuleRunner(widget.library, jobs);
  late final mediaTools = MediaTools(
    widget.library,
    Directory(p.join(p.dirname(widget.library.db.path), 'thumbnails')),
    MediaTools.bundledBin(),
  );
  final selected = <int>{};
  final watchers = <StreamSubscription<FileSystemEvent>>[];
  final playerEvents = <StreamSubscription<dynamic>>[];
  Timer? poll, debounce;
  Timer? progressTimer;
  int? playbackMediaId, activeCollectionId;
  PlaybackSession? playbackSession;
  bool playbackCompleted = false;
  MediaCriteria? activeCriteria;
  String? collectionName;
  Future<void>? scanFuture;
  Future<void>? enrichmentFuture;
  bool enrichmentCancelled = false, enrichmentPaused = false;
  int enrichmentDone = 0, enrichmentTotal = 0;
  Future<void>? playerDisposal;
  bool closing = false;
  String view = 'files', sort = 'recent';
  String? typeFilter;
  LibraryFilter libraryFilter = LibraryFilter();
  Map<int, String> filterActorNames = {}, filterTagNames = {};
  int? minimumRating;
  bool unrated = false,
      grid = false,
      muted = false,
      playingView = false,
      capturing = false;
  Duration previousSeek = Duration.zero;
  bool softwareDecoding = false;
  double subtitleDelay = 0, audioDelay = 0;
  List<Map<String, Object?>> items = [];
  List<String> folders = [];
  Map<String, Object?>? current;
  String query = '';
  String? folder;
  String? error;
  int refreshGeneration = 0;
  bool busy = false, expanded = false, sessionLocking = false;
  void update(VoidCallback action) {
    if (mounted) setState(action);
  }

  Future<void> installUpdate() => guard(() async {
    if (busy || jobs.running) throw StateError('진행 중인 작업을 마친 후 다시 시도하세요.');
    await AppUpdater.instance!.launchHelper(p.dirname(widget.library.db.path));
    update(() => busy = true);
    if (mounted) {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('저장 후 업데이트를 준비하고 있습니다…'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    poll?.cancel();
    debounce?.cancel();
    progressTimer?.cancel();
    for (final watcher in watchers) {
      await watcher.cancel();
    }
    for (final event in playerEvents) {
      await event.cancel();
    }
    await scanFuture;
    await stopEnrichment();
    await player.pause();
    await persistProgress();
    await widget.library.fileOperation(() async {});
    await widget.library.close();
    await widget.privacy?.close();
    await disposePlayer();
    exit(0);
  });

  Future<void> lockSession() => guard(() async {
    if (sessionLocking) return;
    update(() {
      sessionLocking = true;
      capturing = true;
    });
    Navigator.of(context).popUntil((route) => route.isFirst);
    await playback.silence();
    await player.pause();
    await persistProgress();
    await setNativeFullscreen(false);
    await stopEnrichment();
    await windowManager.setPreventClose(false);
    if (mounted) widget.lockNow?.call();
  });

  @override
  void onWindowEnterFullScreen() => syncNativeFullscreen();

  @override
  void onWindowLeaveFullScreen() => syncNativeFullscreen();

  Future<void> syncNativeFullscreen() async {
    nativeFullscreen.value = await windowManager.isFullScreen();
  }

  void fullscreenChanged() => update(() => expanded = nativeFullscreen.value);

  @override
  void onWindowClose() async {
    if (closing) return;
    update(() => closing = true);
    enrichmentCancelled = true;
    try {
      // Keep the engine's event loop alive until video textures are released.
      poll?.cancel();
      debounce?.cancel();
      progressTimer?.cancel();
      for (final watcher in watchers) {
        await watcher.cancel();
      }
      for (final event in playerEvents) {
        await event.cancel();
      }
      await stopEnrichment();
      if (playerDisposal == null) {
        await player.pause();
        await persistProgress();
      }
      await disposePlayer();
      await closeAppWindow();
    } catch (e) {
      update(() {
        error = '종료를 마무리하지 못했습니다: $e';
        closing = false;
      });
    }
  }

  Future<void> disposePlayer() => playerDisposal ??= player.dispose();

  @override
  void initState() {
    super.initState();
    video = VideoController(player);
    windowManager.addListener(this);
    nativeFullscreen.addListener(fullscreenChanged);
    syncNativeFullscreen();
    FocusManager.instance.addEarlyKeyEventHandler(onKey);
    initialize();
  }

  @override
  void dispose() {
    enrichmentCancelled = true;
    windowManager.removeListener(this);
    nativeFullscreen.removeListener(fullscreenChanged);
    progressTimer?.cancel();
    FocusManager.instance.removeEarlyKeyEventHandler(onKey);
    poll?.cancel();
    debounce?.cancel();
    for (final watcher in watchers) {
      watcher.cancel();
    }
    for (final event in playerEvents) {
      event.cancel();
    }
    unawaited(disposePlayer());
    super.dispose();
  }

  Future<void> guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> refresh() async {
    final generation = ++refreshGeneration;
    final selectedId = current?['id'];
    await guard(() async {
      final next = activeCriteria != null
          ? await widget.library.matching(
              activeCriteria!,
              sort: sort,
              filters: [libraryFilter],
            )
          : await widget.library.items(
              filters: [libraryFilter],
              query: query,
              folder: folder,
              type: typeFilter,
              minimumRating: minimumRating,
              unrated: unrated,
              sort: sort,
            );
      final roots = await widget.library.folders();
      final selectedRows = selectedId == null
          ? <Map<String, Object?>>[]
          : await widget.library.db.query(
              'media',
              where: 'id=?',
              whereArgs: [selectedId],
            );
      if (!mounted || generation != refreshGeneration) return;
      if (mounted)
        setState(() {
          items = next;
          folders = roots;
          if (current == null && next.isNotEmpty) current = next.first;
          if (selectedId != null && current?['id'] == selectedId) {
            current = selectedRows.isEmpty ? null : selectedRows.single;
          }
        });
      if (current?['online'] == 0 && playingView) {
        await persistProgress();
        playbackMediaId = null;
        await playback.silence();
        await player.stop();
        update(() => playingView = false);
      }
    });
  }

  KeyEventResult onKey(KeyEvent event) {
    return handleKey(event) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  Future<void> connect() => guard(() async {
    final path = await getDirectoryPath();
    if (path == null) return;
    setState(() => busy = true);
    try {
      await widget.library.connect(path, verifyContents: false);
      await refresh();
      await watchFolders();
    } finally {
      if (mounted) setState(() => busy = false);
    }
    enrichmentPaused = false;
    unawaited(enrichLibrary());
  });
  Future<void> select(Map<String, Object?> item) => guard(() async {
    await persistProgress();
    playbackMediaId = null;
    await playback.silence();
    await player.stop();
    if (mounted)
      setState(() {
        current = item;
        playingView = false;
        view = 'files';
      });
  });
  Future<void> search() async {
    final result = await showDeckDialog<SearchChoice>(
      context: context,
      builder: (context) =>
          LibrarySearchDialog(library: widget.library, query: query),
    );
    if (result == null || !mounted) return;
    if (result.command == 'settings') {
      update(() => view = 'settings');
    } else if (result.command == 'folders') {
      await showFolderManager(context, widget.library, () async {
        await scanFuture;
        await refresh();
        await watchFolders();
      });
    } else {
      activeCriteria = null;
      activeCollectionId = null;
      collectionName = null;
      query = result.item == null ? result.query : '';
      view = 'files';
      await refresh();
      if (result.item != null) await select(result.item!);
    }
  }

  Future<void> edit() async {
    final selectedItem = current;
    if (selectedItem == null) return;
    await playbackSession?.pending;
    final item = await widget.library.mediaById(selectedItem['id'] as int);
    if (!mounted) return;
    final values = await showDeckDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => DetailEditor(
        item: item,
        play: () => openMedia(item),
        rename: () => moveFiles(rename: true),
        external: openExternal,
        relink: relinkFile,
        history: () => showDeckDialog<void>(
          context: context,
          builder: (_) =>
              PlaybackHistoryDialog(library: widget.library, item: item),
        ),
      ),
    );
    if (values != null)
      await guard(() async {
        await widget.library.edit(item['id'] as int, values);
        update(() => current = {...item, ...values});
        await refresh();
      });
  }

  @override
  Widget build(BuildContext context) {
    if (closing) {
      return const Scaffold(
        body: Center(child: Text('재생 위치를 저장하고 종료하고 있습니다…')),
      );
    }
    if (sessionLocking) {
      return Scaffold(
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('잠금을 마무리하지 못했습니다. 앱을 종료해 주세요.'),
                    OutlinedButton(
                      onPressed: onWindowClose,
                      child: const Text('앱 종료'),
                    ),
                  ],
                ),
        ),
      );
    }
    return CallbackShortcuts(
      bindings: const {},
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (error != null)
                MaterialBanner(
                  content: Text(error!),
                  actions: [
                    OutlinedButton(
                      onPressed: () => setState(() => error = null),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              if (busy) const LinearProgressIndicator(),
              if (enrichmentFuture != null || enrichmentPaused)
                Material(
                  color: const Color(0xff1c2229),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: LinearProgressIndicator(
                            value: enrichmentTotal == 0
                                ? null
                                : enrichmentDone / enrichmentTotal,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            enrichmentPaused && enrichmentFuture == null
                                ? '썸네일 준비 중지됨 · 목록을 사용할 수 있습니다'
                                : '썸네일 준비 $enrichmentDone / $enrichmentTotal · 목록을 사용할 수 있습니다',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: enrichmentFuture == null
                              ? () {
                                  enrichmentPaused = false;
                                  unawaited(enrichLibrary());
                                }
                              : enrichmentCancelled
                              ? null
                              : () => update(() {
                                  enrichmentCancelled = true;
                                  enrichmentPaused = true;
                                }),
                          child: Text(
                            enrichmentFuture == null
                                ? '계속'
                                : enrichmentCancelled
                                ? '중지 중…'
                                : '중지',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SideDeck(
                      filterCount: libraryFilter.groupCount,
                      settingsOnly: view == 'settings',
                      items: items,
                      folderDrop: (path, ids) =>
                          moveFiles(destination: path, ids: ids),
                      content: contentPanel,
                      navigation: navigation,
                      toolbar: toolbar,
                      settings: () => command('help'),
                      fileList: VaultFileList(
                        items: items,
                        selected: selected,
                        current: current?['id'] as int?,
                        grid: grid,
                        toggle: (id) => update(() {
                          if (!selected.add(id)) selected.remove(id);
                        }),
                        preview: select,
                        play: openMedia,
                        motionPreview: mediaTools.preview,
                      ),
                      current: current,
                      folders: folders,
                      folder: folder,
                      query: query,
                      expanded: expanded,
                      busy: busy || jobs.running || scanFuture != null,
                      scanning: scanFuture != null,
                      playing: playingView,
                      filters: filters,
                      open: () {
                        if (current != null) openMedia(current!);
                      },
                      connect: connect,
                      search: search,
                      edit: edit,
                      select: select,
                      chooseFolder: (value) {
                        activeCriteria = null;
                        activeCollectionId = null;
                        collectionName = null;
                        folder = value;
                        refresh();
                      },
                      clearSearch: () {
                        query = '';
                        refresh();
                      },
                      searchTerm: (value) {
                        activeCriteria = null;
                        activeCollectionId = null;
                        collectionName = null;
                        query = value;
                        refresh();
                      },
                      rescan: () => guard(() async {
                        setState(() => busy = true);
                        try {
                          await rescanLibrary(notify: true);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      }),
                      rate: (value) => guard(() async {
                        final item = current;
                        if (item == null) return;
                        await widget.library.edit(item['id'] as int, {
                          'rating': value,
                        });
                        if (mounted && current?['id'] == item['id']) {
                          setState(() => current = {...item, 'rating': value});
                        }
                        await refresh();
                      }),
                      stage: playingView
                          ? GestureDetector(
                              key: const ValueKey('video-surface'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => command('pause'),
                              child: Video(
                                controller: video,
                                controls: NoVideoControls,
                              ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                if ((current?['thumbnail'] as String? ?? '')
                                    .isNotEmpty)
                                  Image.file(
                                    File(current!['thumbnail'] as String),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(
                                        Icons.movie_outlined,
                                        size: 64,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                      controls: !playingView || current?['type'] != 'video'
                          ? null
                          : PlaybackControls(
                              player: player,
                              muted: muted,
                              command: command,
                              volume: (value) =>
                                  guard(() => changeVolume(value)),
                              subtitle: externalSubtitle,
                              decoder: decoderSettings,
                              detail: edit,
                              rating: current?['rating'] as int?,
                              rate: rateTargets,
                            ),
                    ),
                    if (selected.isNotEmpty && view == 'files')
                      Positioned(
                        left: 0,
                        right: expanded
                            ? 0
                            : MediaQuery.sizeOf(context).width <= 1280
                            ? 340
                            : 370,
                        bottom: 24,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(width: 570, child: selectionBar),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
