part of 'main.dart';

extension _ExtendedFeatures on _VaultHomeState {
  Future<void> persistProgress({bool completed = false}) async {
    final id = playbackMediaId;
    final position = player.state.position, duration = player.state.duration;
    if (id == null || duration <= Duration.zero) return;
    await playbackSession?.pending;
    await widget.library.saveResume(
      id,
      position,
      duration,
      completed: completed,
    );
  }

  Future<void> showScenes() async {
    final item = current;
    if (item == null || item['type'] != 'video') return;
    await showDeckDialog<void>(
      context: context,
      builder: (_) => ScenesDialog(
        library: widget.library,
        mediaId: item['id'] as int,
        position: () => playbackMediaId == item['id']
            ? player.state.position
            : Duration(milliseconds: item['resume_ms'] as int),
        jump: (position) => guard(() async {
          if (playbackMediaId == item['id'] && playingView) {
            await player.seek(position);
            await persistProgress();
          } else {
            await openMedia(item, position: position);
          }
        }),
      ),
    );
  }

  Future<void> chooseThumbnail() => guard(() async {
    final item = current;
    if (item == null) return;
    await showDeckDialog<bool>(
      context: context,
      builder: (_) => ThumbnailDialog(
        item: item,
        tools: mediaTools,
        position: playbackMediaId == item['id']
            ? player.state.position.inMilliseconds / 1000
            : 0,
      ),
    );
    await refresh();
  });
  Future<void> saveCurrentCollection() async {
    await showDeckDialog<bool>(
      context: context,
      builder: (_) => CriteriaDialog(
        folders: folders,
        initial: MediaCriteria.fromJson({
          ...(activeCriteria ??
                  MediaCriteria(
                    query: query,
                    folder: folder,
                    type: typeFilter,
                    minimumRating: minimumRating,
                    unrated: unrated,
                  ))
              .toJson(),
          'filters': [
            ...?activeCriteria?.filters,
            if (!libraryFilter.isEmpty) libraryFilter,
          ].map((f) => f.toJson()).toList(),
        }),
        save: (draft) async {
          await widget.library.saveCollection(draft.name, draft.criteria);
        },
      ),
    );
  }

  Future<void> openCollection(Map<String, Object?> row) async {
    activeCollectionId = row['id'] as int;
    collectionName = row['name'] as String;
    activeCriteria = MediaCriteria.decode(row['criteria'] as String);
    libraryFilter = LibraryFilter();
    view = 'files';
    selected.clear();
    await refresh();
  }

  Future<void> clearCollection() async {
    activeCollectionId = null;
    collectionName = null;
    activeCriteria = null;
    await refresh();
  }

  Future<void> prepareFileWork() async {
    await scanFuture;
    await stopEnrichment();
    await persistProgress();
    playbackMediaId = null;
    await playback.silence();
    await player.stop();
    update(() => playingView = false);
  }

  Future<void> nfoImport() => guard(() async {
    final item = current;
    if (item == null) return;
    final picked = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'NFO', extensions: ['nfo', 'xml']),
      ],
    );
    if (picked == null || !mounted) return;
    final service = NfoService(widget.library);
    final data = await service.read(File(picked.path));
    if (!mounted) return;
    final confirmed = await showDeckDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NFO 가져오기'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Text(
              '${item['title']}에 다음 기록을 적용합니다.\n\n${data.fields.entries.map((entry) => '${entry.key}: ${entry.value ?? '미평가'}').join('\n')}\n\n이어보기: ${data.resumeMs == null ? '변경 없음' : sceneTime(data.resumeMs!)}\n장면 북마크: ${data.bookmarks.length}개\n\n적용 전 현재 카탈로그를 자동 백업합니다.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('가져오기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await prepareFileWork();
    await widget.library.exportTo(
      File(
        p.join(
          p.dirname(widget.library.db.path),
          'before-nfo-${DateTime.now().microsecondsSinceEpoch}.json',
        ),
      ),
    );
    await service.apply(item['id'] as int, data);
    await refresh();
  });
  Future<void> nfoExport() => guard(() async {
    final item = current;
    if (item == null) return;
    await persistProgress();
    final target = await getSaveLocation(
      suggestedName:
          '${p.basenameWithoutExtension(item['path'] as String)}.nfo',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'NFO', extensions: ['nfo']),
      ],
    );
    if (target == null || !mounted) return;
    var overwrite = false;
    if (await File(target.path).exists()) {
      if (!mounted) return;
      overwrite =
          await showDeckDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('기존 NFO 교체'),
              content: const Text('기존 파일을 백업한 뒤 새 메타데이터로 교체합니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('백업 후 교체'),
                ),
              ],
            ),
          ) ??
          false;
      if (!overwrite) return;
    }
    await NfoService(
      widget.library,
    ).write(item['id'] as int, File(target.path), overwrite: overwrite);
  });
  void settingsAction(String action) {
    update(() => view = 'files');
    switch (action) {
      case 'grid':
        update(() => grid = !grid);
      case 'selectAll':
        update(() {
          if (selected.length == items.length) {
            selected.clear();
          } else {
            selected.addAll(items.map((item) => item['id'] as int));
          }
        });
      case 'rescan':
        guard(rescanLibrary);
      case 'decoder':
        decoderSettings();
      case 'organize':
        update(() => view = 'organize');
      case 'collection':
        saveCurrentCollection();
      case 'resume':
        if (current != null) openMedia(current!);
      case 'restart':
        if (current != null) openMedia(current!, fromStart: true);
      case 'scenes':
        showScenes();
      case 'thumbnail':
        chooseThumbnail();
      case 'nfoImport':
        nfoImport();
      case 'nfoExport':
        nfoExport();
      case 'history':
        moveFiles(ids: []);
    }
  }
}
