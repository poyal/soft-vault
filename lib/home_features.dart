part of 'main.dart';

extension _HomeFeatures on _VaultHomeState {
  Future<void> relinkFile() => guard(() async {
    final item = current;
    if (item == null) return;
    final file = await openFile();
    if (file == null || !mounted) return;
    final duplicates = await widget.library.db.query(
      'media',
      where: 'path = ? AND id != ?',
      whereArgs: [file.path, item['id']],
    );
    var replace = false;
    if (duplicates.isNotEmpty) {
      replace =
          await showDeckDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('파일 연결 교체'),
              content: const Text(
                '선택한 경로가 이미 등록되어 있습니다. 해당 경로의 목록 항목을 현재 파일의 기록으로 교체합니다. 실제 파일은 삭제하지 않습니다.',
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('기록 교체'),
                ),
              ],
            ),
          ) ??
          false;
      if (!replace) return;
    }
    await prepareFileWork();
    await widget.library.relink(
      item['id'] as int,
      file.path,
      replaceIndexEntry: replace,
    );
    update(() => current = null);
    await refresh();
    await watchFolders();
  });
  Future<void> externalSubtitle() => guard(() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: '자막', extensions: ['srt', 'ass', 'ssa', 'smi']),
      ],
    );
    if (file != null)
      await player.setSubtitleTrack(SubtitleTrack.uri(file.path));
  });
  Future<void> decoderSettings() async {
    await showDeckDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('디코더 · 싱크'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: player.state.track.audio.id,
                  decoration: const InputDecoration(labelText: '음성 트랙'),
                  items: player.state.tracks.audio
                      .map(
                        (track) => DropdownMenuItem(
                          value: track.id,
                          child: Text(
                            track.title ?? track.language ?? track.id,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id != null)
                      player.setAudioTrack(
                        player.state.tracks.audio.firstWhere(
                          (track) => track.id == id,
                        ),
                      );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      player.state.tracks.subtitle.any(
                        (track) => track.id == player.state.track.subtitle.id,
                      )
                      ? player.state.track.subtitle.id
                      : null,
                  decoration: const InputDecoration(labelText: '자막 트랙'),
                  items: player.state.tracks.subtitle
                      .map(
                        (track) => DropdownMenuItem(
                          value: track.id,
                          child: Text(
                            track.title ?? track.language ?? track.id,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id != null)
                      player.setSubtitleTrack(
                        player.state.tracks.subtitle.firstWhere(
                          (track) => track.id == id,
                        ),
                      );
                  },
                ),
                OutlinedButton(
                  onPressed: externalSubtitle,
                  child: const Text('외부 자막 열기'),
                ),
                SwitchListTile(
                  title: const Text('소프트웨어 디코딩'),
                  subtitle: const Text('하드웨어 가속 오류 시 사용'),
                  value: softwareDecoding,
                  onChanged: (value) async {
                    await (player.platform as NativePlayer).setProperty(
                      'hwdec',
                      value ? 'no' : 'auto',
                    );
                    update(() => softwareDecoding = value);
                  },
                ),
                Text('자막 지연 ${subtitleDelay.toStringAsFixed(1)}초'),
                Slider(
                  value: subtitleDelay,
                  min: -5,
                  max: 5,
                  divisions: 100,
                  onChanged: (value) {
                    update(() => subtitleDelay = value);
                    guard(
                      () => (player.platform as NativePlayer).setProperty(
                        'sub-delay',
                        '$value',
                      ),
                    );
                  },
                ),
                Text('음성 지연 ${audioDelay.toStringAsFixed(1)}초'),
                Slider(
                  value: audioDelay,
                  min: -5,
                  max: 5,
                  divisions: 100,
                  onChanged: (value) {
                    update(() => audioDelay = value);
                    guard(
                      () => (player.platform as NativePlayer).setProperty(
                        'audio-delay',
                        '$value',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  List<int> get targets => selected.isNotEmpty
      ? selected.toList()
      : [if (current != null) current!['id'] as int];
  Future<void> initialize() => guard(() async {
    await windowManager.setPreventClose(true);
    await keys.load();
    await jobs.recover();
    if (closing || !mounted) return;
    await refresh();
    await watchFolders();
    if (closing || !mounted) return;
    playerEvents.add(player.stream.playing.listen((_) => update(() {})));
    playerEvents.add(player.stream.tracks.listen((_) => update(() {})));
    playerEvents.add(
      player.stream.position.listen((position) {
        if (playbackMediaId == null || closing) return;
        if (playbackCompleted &&
            player.state.playing &&
            position > Duration.zero &&
            position < player.state.duration * .9) {
          playbackCompleted = false;
          playbackSession = newPlaybackSession(playbackMediaId!, Duration.zero);
        }
        final session = playbackSession;
        if (session != null) {
          guard(
            () => session.observe(
              position,
              player.state.duration,
              player.state.playing,
            ),
          );
        }
      }),
    );
    playerEvents.add(
      player.stream.error.listen((message) => update(() => error = message)),
    );
    poll = Timer.periodic(const Duration(seconds: 30), (_) => rescanLibrary());
    progressTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => guard(persistProgress),
    );
    playerEvents.add(
      player.stream.completed.listen((completed) {
        if (completed) {
          playbackCompleted = true;
          guard(() => persistProgress(completed: true));
        }
      }),
    );
    await rescanLibrary();
    if (mounted &&
        folders.isEmpty &&
        items.isEmpty &&
        await widget.library.readSetting('welcome_seen') != true) {
      await widget.library.setting('welcome_seen', true);
      if (!mounted) return;
      final start = await showDeckDialog<bool>(
        context: context,
        builder: (_) => const WelcomeDialog(),
      );
      if (start == true) await connect();
    }
  });
  Future<void> watchFolders() async {
    for (final watcher in watchers) {
      await watcher.cancel();
    }
    watchers.clear();
    if (closing || !mounted) return;
    for (final root in await widget.library.folders()) {
      if (!await Directory(root).exists()) continue;
      if (closing || !mounted) return;
      try {
        watchers.add(
          Directory(root).watch(recursive: true).listen((_) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 800), rescanLibrary);
          }, onError: (_) {}),
        );
      } on FileSystemException {
        /* Periodic scanning remains available. */
      }
    }
  }

  Future<void> rescanLibrary({bool notify = false}) async {
    if (closing || scanFuture != null || jobs.running || !mounted) return;
    final work = guard(() async {
      for (final root in await widget.library.folders()) {
        await widget.library.scan(root, verifyContents: false);
      }
      await refresh();
      await rules.runAutomatic(
        skipIds: {if (playbackMediaId != null) playbackMediaId!},
      );
      await refresh();
      if (notify && mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('전체 폴더 새로고침을 마쳤습니다.')));
    });
    scanFuture = work;
    if (mounted) update(() {});
    try {
      await work;
    } finally {
      scanFuture = null;
      if (mounted) update(() {});
    }
    unawaited(enrichLibrary());
  }

  Future<void> enrichLibrary() async {
    if (closing || !mounted || enrichmentPaused || enrichmentFuture != null)
      return;
    enrichmentCancelled = false;
    final work = guard(() async {
      await mediaTools.enrich(
        cancelled: () => enrichmentCancelled || closing || !mounted,
        progress: (done, total) => update(() {
          enrichmentDone = done;
          enrichmentTotal = total;
        }),
        changed: refresh,
      );
    });
    update(() {
      enrichmentFuture = work;
    });
    try {
      await work;
    } finally {
      update(() => enrichmentFuture = null);
    }
  }

  Future<void> stopEnrichment() async {
    enrichmentCancelled = true;
    await enrichmentFuture;
  }

  Future<void> openMedia(
    Map<String, Object?> item, {
    bool fromStart = false,
    Duration? position,
  }) => guard(() async {
    await persistProgress();
    item = await widget.library.mediaById(item['id'] as int);
    if (item['online'] == 0 || !await File(item['path'] as String).exists())
      throw FileSystemException('오프라인 파일입니다.', item['path'] as String);
    if (item['type'] != 'video') throw StateError('영상 파일만 재생할 수 있습니다.');
    playbackMediaId = null;
    playbackSession = null;
    playbackCompleted = false;
    final resume =
        position ??
        (fromStart
            ? Duration.zero
            : Duration(milliseconds: item['resume_ms'] as int));
    await playback.open(item['path'] as String, start: resume);
    playbackMediaId = item['id'] as int;
    playbackSession = newPlaybackSession(playbackMediaId!, resume);
    await (player.platform as NativePlayer).setProperty('mute', 'no');
    update(() {
      current = item;
      playingView = true;
      view = 'files';
      muted = false;
    });
  });
  PlaybackSession newPlaybackSession(int mediaId, Duration start) {
    final startedAt = DateTime.now();
    return PlaybackSession(() async {
      await widget.library.recordPlayback(mediaId, startedAt, start);
      if (mounted && !closing) unawaited(refresh());
    });
  }

  Future<void> rateTargets(int? value) => guard(() async {
    await widget.library.batchEdit(targets, rating: value, setRating: true);
    await refresh();
  });
  Future<void> seekBy(int seconds) async {
    previousSeek = player.state.position;
    final ms = (previousSeek.inMilliseconds + seconds * 1000).clamp(
      0,
      player.state.duration.inMilliseconds,
    );
    await player.seek(Duration(milliseconds: ms));
  }

  Future<void> changeVolume(double value) async {
    final raising = value > player.state.volume;
    await playback.setVolume(value);
    if (raising) {
      await (player.platform as NativePlayer).setProperty('mute', 'no');
      update(() => muted = false);
    }
  }

  Future<void> command(String command) => guard(() async {
    if (view != 'files' && !['search', 'help'].contains(command)) return;
    if (command.startsWith('rate')) {
      await rateTargets(int.parse(command.substring(4)));
      return;
    }
    switch (command) {
      case 'clearRating':
        await rateTargets(null);
        return;
      case 'search':
        await search();
        return;
      case 'move':
        await moveFiles();
        return;
      case 'detail':
      case 'actors':
        await edit();
        return;
      case 'tags':
        if (selected.isNotEmpty) {
          await batchTags();
        } else {
          await edit();
        }
        return;
      case 'help':
        if (expanded) {
          await setNativeFullscreen(false);
          expanded = false;
        }
        update(() => view = 'settings');
        return;
    }
    if (view != 'files' || current == null) return;
    if (command == 'next' || command == 'previous') {
      final index = items.indexWhere((item) => item['id'] == current!['id']);
      final next = index + (command == 'next' ? 1 : -1);
      if (next >= 0 && next < items.length) {
        if (playingView) {
          await openMedia(items[next]);
        } else {
          await select(items[next]);
        }
      }
      return;
    }
    if (current!['type'] != 'video') return;
    if (command == 'pause' && !playingView) {
      await openMedia(current!);
      return;
    }
    if (!playingView) return;
    switch (command) {
      case 'pause':
        await player.playOrPause();
        await persistProgress();
      case 'back':
        await seekBy(-5);
      case 'forward':
        await seekBy(5);
      case 'preciseBack':
        await seekBy(-1);
      case 'preciseForward':
        await seekBy(1);
      case 'volumeUp':
        await changeVolume(player.state.volume + 5);
      case 'volumeDown':
        await changeVolume(player.state.volume - 5);
      case 'mute':
        await (player.platform as NativePlayer).setProperty(
          'mute',
          muted ? 'no' : 'yes',
        );
        update(() => muted = !muted);
      case 'fullscreen':
        final nextFullscreen = !await windowManager.isFullScreen();
        await setNativeFullscreen(nextFullscreen);
        update(() => expanded = nextFullscreen);
      case 'slower':
        await player.setRate((player.state.rate - .25).clamp(.25, 3));
      case 'faster':
        await player.setRate((player.state.rate + .25).clamp(.25, 3));
      case 'normalSpeed':
        await player.setRate(1);
      case 'undoSeek':
        final position = previousSeek;
        previousSeek = player.state.position;
        await player.seek(position);
    }
  });
  bool handleKey(KeyEvent event) {
    if (closing) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) guard(playback.panic);
      return true;
    }
    if (capturing || ModalRoute.of(context)?.isCurrent == false) return false;
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus?.widget is EditableText ||
        focus?.findAncestorStateOfType<EditableTextState>() != null)
      return false;
    if ([
          LogicalKeyboardKey.digit0,
          LogicalKeyboardKey.numpad0,
        ].contains(event.logicalKey) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      guard(playback.silence);
      return true;
    }
    final action = keys.resolve(event);
    // Settings owns activation/navigation; global search and help still work.
    if (view == 'settings' && action != 'search' && action != 'help')
      return false;
    if (action == null) return false;
    if (event is KeyRepeatEvent &&
        ![
          'back',
          'forward',
          'preciseBack',
          'preciseForward',
          'volumeUp',
          'volumeDown',
        ].contains(action))
      return true;
    command(action);
    return true;
  }

  Future<void> moveFiles({
    String? destination,
    bool rename = false,
    List<int>? ids,
  }) async {
    await showFileJobs(
      context,
      widget.library,
      jobs,
      ids ?? targets,
      target: destination,
      rename: rename,
      prepare: () async {
        await scanFuture;
        await stopEnrichment();
        await persistProgress();
        playbackMediaId = null;
        await playback.silence();
        await player.stop();
        update(() => playingView = false);
      },
      changed: () async {
        if (current != null) {
          final row = await widget.library.db.query(
            'media',
            where: 'id = ?',
            whereArgs: [current!['id']],
          );
          update(() => current = row.isEmpty ? null : row.single);
        }
        await refresh();
      },
    );
  }

  Future<void> batchTags() async {
    final controller = TextEditingController();
    var remove = false;
    final save = await showDeckDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('태그 일괄 편집 · ${targets.length}개 파일'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '태그 · 쉼표로 구분'),
                ),
                SwitchListTile(
                  value: remove,
                  onChanged: (value) => update(() => remove = value),
                  title: const Text('입력한 태그 제거'),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
    if (save == true)
      await guard(() async {
        update(() => busy = true);
        try {
          await widget.library.batchEdit(
            targets,
            tags: controller.text,
            removeTags: remove,
          );
          await refresh();
        } finally {
          update(() => busy = false);
        }
      });
  }

  Future<void> filters() => guard(() async {
    final entities = await Future.wait([
      widget.library.entities('actors'),
      widget.library.entities('tags'),
    ]);
    filterActorNames = {
      for (final row in entities[0]) row['id'] as int: row['name'] as String,
    };
    filterTagNames = {
      for (final row in entities[1]) row['id'] as int: row['name'] as String,
    };
    if (!mounted) return;
    final result = await showDeckDialog<LibraryFilter>(
      context: context,
      builder: (_) => LibraryFilterDialog(
        initial: libraryFilter,
        actors: entities[0],
        tags: entities[1],
        validate: (draft) async {
          final latest = await Future.wait([
            widget.library.entities('actors'),
            widget.library.entities('tags'),
          ]);
          return draft.withIds(
            actors: draft.actorIds.where(
              (id) => latest[0].any((r) => r['id'] == id),
            ),
            tags: draft.tagIds.where(
              (id) => latest[1].any((r) => r['id'] == id),
            ),
          );
        },
      ),
    );
    if (result != null) {
      libraryFilter = result;
      minimumRating = null;
      unrated = false;
      selected.clear();
      await refresh();
    }
  });

  void changeLibraryFilter(LibraryFilter value) {
    update(() => libraryFilter = value);
    selected.clear();
    guard(refresh);
  }

  Future<void> exportBackup() => guard(() async {
    final location = await getSaveLocation(
      suggestedName: 'soft-vault-backup.json',
    );
    if (location != null) await widget.library.exportTo(File(location.path));
  });
  Future<void> restoreBackup() => guard(() async {
    if (jobs.running) throw StateError('파일 작업이 끝난 뒤 복원하세요.');
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: '백업', extensions: ['json']),
      ],
    );
    if (file == null || !mounted) return;
    final confirmed = await showDeckDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('라이브러리 백업 복원'),
        content: const Text(
          '현재 메타데이터를 백업 내용으로 교체합니다. 현재 기록은 자동 백업하며 원본 미디어 파일은 변경하지 않습니다.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('복원'),
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
          'before-restore-${DateTime.now().millisecondsSinceEpoch}.json',
        ),
      ),
    );
    await widget.library.restoreFrom(File(file.path));
    update(() {
      current = null;
      selected.clear();
      playingView = false;
    });
    await refresh();
    await watchFolders();
  });
  Future<void> openExternal() => guard(() async {
    if (current == null) return;
    final path = current!['path'] as String;
    if (!await File(path).exists())
      throw FileSystemException('파일이 오프라인입니다.', path);
    // A file URI is handled by the desktop shell; no command text is constructed.
    if (Platform.isWindows) {
      await Process.run('rundll32.exe', [
        'url.dll,FileProtocolHandler',
        Uri.file(path).toString(),
      ]);
    } else {
      await Process.run('open', [path]);
    }
  });
  Widget get navigation => Container(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xff303c48))),
    ),
    child: Row(
      children: [
        for (final entry in {
          'files': ('파일', 'film'),
          'actors': ('배우', 'person'),
          'tags': ('태그', 'tag'),
        }.entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 7),
              child: OutlinedButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  backgroundColor: view == entry.key
                      ? const Color(0xff2a3b4b)
                      : Colors.transparent,
                  foregroundColor: view == entry.key
                      ? const Color(0xffa9cbe1)
                      : DeckDesign.muted,
                ),
                onPressed: () => update(() => view = entry.key),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DesignIcon(
                      entry.value.$2,
                      size: 15,
                      color: view == entry.key
                          ? const Color(0xffa9cbe1)
                          : DeckDesign.muted,
                    ),
                    const SizedBox(width: 7),
                    Text(entry.value.$1, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        DeckIconButton('search', tooltip: '검색', onPressed: search, size: 16),
      ],
    ),
  );
  Widget get toolbar => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      children: [
        if (activeCriteria != null)
          InputChip(
            label: Text(
              collectionName ?? '스마트 컬렉션',
              style: const TextStyle(fontSize: 14),
            ),
            onDeleted: clearCollection,
          ),
        Row(
          children: [
            const Text(
              '정렬',
              style: TextStyle(fontSize: 14, color: DeckDesign.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  color: DeckDesign.surface,
                  border: Border.all(color: DeckDesign.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButton<String>(
                  value: sort,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  icon: const DesignIcon('down', size: 16),
                  items:
                      {
                            'recent': '최근 추가순',
                            'name': '이름순',
                            'rating': '평점순',
                            'duration': '길이순',
                          }.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    sort = value;
                    refresh();
                  },
                ),
              ),
            ),
          ],
        ),
        if (!libraryFilter.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (libraryFilter.playback != PlaybackFilter.all)
                  InputChip(
                    label: Text(libraryFilter.playback.label),
                    onDeleted: () => changeLibraryFilter(
                      libraryFilter.withPlayback(PlaybackFilter.all),
                    ),
                  ),
                if (libraryFilter.rating != null || libraryFilter.unrated)
                  InputChip(
                    label: Text(
                      libraryFilter.ratingLabel,
                      style: const TextStyle(fontSize: 14),
                    ),
                    onDeleted: () =>
                        changeLibraryFilter(libraryFilter.withoutRating()),
                  ),
                for (final kind in ['actors', 'tags']) ...[
                  if ((kind == 'actors'
                          ? libraryFilter.actorIds
                          : libraryFilter.tagIds)
                      .isNotEmpty)
                    ActionChip(
                      label: Text(
                        '${kind == 'actors' ? '배우' : '태그'} · ${(kind == 'actors' ? libraryFilter.actorsAll : libraryFilter.tagsAll) ? '모두' : '하나라도'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      onPressed: filters,
                    ),
                  for (final id
                      in (kind == 'actors'
                              ? libraryFilter.actorIds
                              : libraryFilter.tagIds)
                          .take(2))
                    InputChip(
                      label: SizedBox(
                        width: 125,
                        child: Text(
                          (kind == 'actors'
                                  ? filterActorNames[id]
                                  : filterTagNames[id]) ??
                              '삭제된 항목',
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: filters,
                      onDeleted: () => changeLibraryFilter(
                        kind == 'actors'
                            ? libraryFilter.withIds(
                                actors: libraryFilter.actorIds.where(
                                  (v) => v != id,
                                ),
                              )
                            : libraryFilter.withIds(
                                tags: libraryFilter.tagIds.where(
                                  (v) => v != id,
                                ),
                              ),
                      ),
                    ),
                  if ((kind == 'actors'
                              ? libraryFilter.actorIds
                              : libraryFilter.tagIds)
                          .length >
                      2)
                    ActionChip(
                      label: Text(
                        '외 ${(kind == 'actors' ? libraryFilter.actorIds : libraryFilter.tagIds).length - 2}개',
                      ),
                      onPressed: filters,
                    ),
                ],
                OutlinedButton(
                  onPressed: () => changeLibraryFilter(LibraryFilter()),
                  child: const Text('필터 해제'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
  Widget? get contentPanel {
    final panel = switch (view) {
      'organize' => OrganizePanel(
        library: widget.library,
        rules: rules,
        openCollection: openCollection,
        openMedia: select,
        prepare: prepareFileWork,
        changed: refresh,
      ),
      'actors' || 'tags' => CatalogPanel(
        key: ValueKey(view),
        library: widget.library,
        kind: view,
        openAll: () {
          activeCriteria = null;
          activeCollectionId = null;
          collectionName = null;
          query = '';
          folder = null;
          typeFilter = null;
          minimumRating = null;
          unrated = false;
          libraryFilter = LibraryFilter();
          selected.clear();
          view = 'files';
          refresh();
        },
        open: (value) {
          activeCriteria = null;
          activeCollectionId = null;
          collectionName = null;
          query = value;
          view = 'files';
          refresh();
        },
        changed: refresh,
      ),
      'settings' => SettingsPanel(
        installUpdate: busy || jobs.running ? null : installUpdate,
        privacy: widget.privacy,
        lockNow: widget.lockNow == null || busy || jobs.running
            ? null
            : lockSession,
        keys: keys,
        metadataChanged: refresh,
        folderCount: folders.length,
        mediaTitle: current?['title'] as String?,
        busy: busy,
        connect: connect,
        folders: () => showFolderManager(context, widget.library, () async {
          await scanFuture;
          await refresh();
          await watchFolders();
        }),
        action: settingsAction,
        close: () => update(() => view = 'files'),
        capturing: (value) => capturing = value,
        backup: exportBackup,
        restore: restoreBackup,
        external: openExternal,
      ),
      _ => null,
    };
    if (panel == null) return null;
    if (view == 'settings') return panel;
    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xff323d49))),
          ),
          child: Row(
            children: [
              const DesignIcon('panel', size: 18),
              const SizedBox(width: 20),
              const Text(
                '라이브러리',
                style: TextStyle(color: Color(0xffb3c1cd), fontSize: 14),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Icon(Icons.chevron_right, size: 16),
              ),
              Text(
                view == 'actors'
                    ? '배우'
                    : view == 'tags'
                    ? '태그'
                    : view == 'organize'
                    ? '라이브러리 정리'
                    : '설정',
                style: const TextStyle(fontSize: 14),
              ),
              const Spacer(),
              DeckIconButton(
                'search',
                onPressed: search,
                tooltip: '검색 · Ctrl/Cmd+K',
              ),
              const SizedBox(width: 10),
              const KeyCap('Ctrl K'),
            ],
          ),
        ),
        Expanded(child: panel),
      ],
    );
  }

  Widget get selectionBar => Material(
    color: const Color(0xf52b4051),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Color(0xff52758d)),
    ),
    elevation: 12,
    child: Padding(
      padding: const EdgeInsets.all(9),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${selected.length}개 선택', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 9),
          for (var rating = 1; rating <= 5; rating++)
            IconButton(
              onPressed: () => rateTargets(rating),
              tooltip: '일괄 $rating점',
              icon: const Text(
                '★',
                style: TextStyle(fontSize: 15, color: DeckDesign.gold),
              ),
            ),
          OutlinedButton(
            onPressed: () => rateTargets(null),
            child: const Text('평점 초기화'),
          ),
          OutlinedButton(onPressed: batchTags, child: const Text('태그 편집')),
          OutlinedButton(onPressed: moveFiles, child: const Text('폴더 이동')),
          IconButton(
            onPressed: () => update(selected.clear),
            tooltip: '선택 해제',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}
