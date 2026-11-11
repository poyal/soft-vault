import 'metadata_workspace.dart';
import 'settings_components.dart';
import 'design.dart';
import 'update_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'key_bindings.dart';
import 'privacy_lock.dart';
import 'privacy_ui.dart';

class SettingsPanel extends StatefulWidget {
  final Future<void> Function()? installUpdate;
  final PrivacyLock? privacy;
  final Future<void> Function()? lockNow;
  final KeyBindings keys;
  final ValueChanged<bool> capturing;
  final VoidCallback backup, restore, external, connect, folders, close;
  final ValueChanged<String> action;
  final int folderCount;
  final String? mediaTitle;
  final bool busy;
  final VoidCallback? metadataChanged;
  const SettingsPanel({
    super.key,
    this.metadataChanged,
    this.installUpdate,
    this.privacy,
    this.lockNow,
    required this.keys,
    required this.folderCount,
    required this.mediaTitle,
    required this.busy,
    required this.connect,
    required this.folders,
    required this.action,
    required this.close,
    required this.capturing,
    required this.backup,
    required this.restore,
    required this.external,
  });
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  Future<T?> settingsDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) => showDeckDialog<T>(
    context: context,
    builder: (dialogContext) => SettingsTheme(child: builder(dialogContext)),
  );
  final presetName = TextEditingController(text: '내 단축키');
  Map<String, dynamic> presets = {};
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await widget.keys.library.readSetting('shortcut_presets');
    if (mounted)
      setState(
        () => presets = data is Map ? Map<String, dynamic>.from(data) : {},
      );
  }

  @override
  void dispose() {
    presetName.dispose();
    super.dispose();
  }

  Future<void> capture(String command, int slot) async {
    widget.capturing(true);
    String? error;
    try {
      await settingsDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent ||
                  [
                    LogicalKeyboardKey.controlLeft,
                    LogicalKeyboardKey.controlRight,
                    LogicalKeyboardKey.shiftLeft,
                    LogicalKeyboardKey.shiftRight,
                    LogicalKeyboardKey.altLeft,
                    LogicalKeyboardKey.altRight,
                    LogicalKeyboardKey.metaLeft,
                    LogicalKeyboardKey.metaRight,
                  ].contains(event.logicalKey))
                return KeyEventResult.handled;
              final failure = widget.keys.assign(
                command,
                slot,
                eventChord(event),
              );
              if (failure != null) {
                update(() => error = failure);
              } else {
                Navigator.pop(context);
              }
              return KeyEventResult.handled;
            },
            child: AlertDialog(
              title: Text(
                '${KeyBindings.labels[command]} · ${slot == 0 ? '기본키' : '보조키'}',
              ),
              content: Text(error ?? '지정할 키 조합을 누르세요.\nEsc와 0은 변경할 수 없습니다.'),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        ),
      );
      await widget.keys.save();
      if (mounted) setState(() {});
    } finally {
      widget.capturing(false);
    }
  }

  String tab = '라이브러리';
  Future<void> managePresets() async {
    await settingsDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('단축키 프리셋'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: presetName,
                  decoration: const InputDecoration(labelText: '프리셋 이름'),
                ),
                const SizedBox(height: 16),
                for (final name in presets.keys)
                  ListTile(
                    title: Text(name),
                    onTap: () async {
                      widget.keys.values = (presets[name] as Map).map(
                        (key, value) => MapEntry(
                          key as String,
                          (value as List).cast<String>(),
                        ),
                      );
                      await widget.keys.save();
                      if (context.mounted) Navigator.pop(context);
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
            FilledButton(
              onPressed: () async {
                if (presetName.text.trim().isEmpty) return;
                presets[presetName.text.trim()] = widget.keys.values.map(
                  (key, value) => MapEntry(key, List<String>.from(value)),
                );
                await widget.keys.library.setting('shortcut_presets', presets);
                update(() {});
              },
              child: const Text('프리셋 저장'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget keyButton(String command, int slot) {
    final values = widget.keys.values[command] ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: OutlinedButton(
        onPressed: () => capture(command, slot),
        child: Text(
          slot >= values.length ? '지정 안 됨' : chordLabel(values[slot]),
        ),
      ),
    );
  }

  Widget section(String title, String description, List<Widget> children) =>
      SettingsSection(
        title: title,
        description: description,
        children: [
          for (var i = 0; i < children.length; i++)
            children[i] is SettingsRow
                ? children[i]
                : SettingsRow(
                    title: switch (title) {
                      '연결 폴더' => i == 0 ? '새 폴더 추가' : '연결된 폴더 관리',
                      '재생 기본 동작' => i == 0 ? '시작 음량' : '재생 위치 기억',
                      '선택한 영상' => '외부 플레이어',
                      '카탈로그와 기록 백업' => '기록 내보내기',
                      '백업 복원' => '저장한 기록 불러오기',
                      _ => title,
                    },
                    control: children[i],
                  ),
        ],
      );

  Widget action(String label, String id, {bool enabled = true}) => SettingsRow(
    title:
        const {
          'grid': '보기 방식',
          'selectAll': '파일 선택',
          'collection': '컬렉션',
          'organize': '정리 도구',
          'history': '작업 기록',
          'rescan': '폴더 갱신',
          'resume': '이어서 보기',
          'restart': '재생 위치',
          'decoder': '재생 옵션',
          'scenes': '장면 관리',
          'thumbnail': '미리보기 이미지',
          'nfoImport': '메타데이터 읽기',
          'nfoExport': '메타데이터 저장',
        }[id] ??
        '영상 작업',
    description: !enabled ? '영상을 먼저 선택해 주세요.' : null,
    control: OutlinedButton(
      onPressed: enabled && !widget.busy ? () => widget.action(id) : null,
      child: Text(label),
    ),
  );

  List<Widget> get librarySettings => [
    section(
      '연결 폴더',
      '${widget.folderCount}개 폴더 연결됨 · 원본 영상은 연결한 폴더에 그대로 보관합니다.',
      [
        FilledButton.icon(
          onPressed: widget.busy ? null : widget.connect,
          icon: const Icon(Icons.add, size: 17),
          label: const Text('폴더 연결'),
        ),
        OutlinedButton(
          onPressed: widget.folders,
          child: const Text('연결 폴더 관리'),
        ),
      ],
    ),
    section('목록과 정리', '보기 방식을 바꾸고, 현재 조건을 저장하거나 파일을 정리합니다.', [
      action('썸네일 · 목록 보기', 'grid'),
      action('전체 선택', 'selectAll'),
      action('현재 조건을 컬렉션으로 저장', 'collection'),
      action('스마트 컬렉션 · 중복 · 이동 규칙', 'organize'),
      action('파일 작업 기록', 'history'),
    ]),
  ];

  List<Widget> get playbackSettings => [
    section(
      '재생 기본 동작',
      '영상을 열 때마다 볼륨 0%로 시작하고 마지막 위치에서 이어봅니다.\n영상 화면을 클릭하면 재생·일시정지가 전환됩니다. Esc는 소리를 끄고 창을 최소화합니다.',
      [
        const Chip(label: Text('시작 음량 0%')),
        const Chip(label: Text('마지막 위치 기억')),
      ],
    ),
    section('선택한 영상', widget.mediaTitle ?? '목록에서 영상을 선택하면 아래 기능을 사용할 수 있습니다.', [
      action('이어보기', 'resume', enabled: widget.mediaTitle != null),
      action('처음부터 재생', 'restart', enabled: widget.mediaTitle != null),
      action('음성 · 자막 · 디코더', 'decoder', enabled: widget.mediaTitle != null),
      action('장면 북마크 · 메모', 'scenes', enabled: widget.mediaTitle != null),
      action('대표 썸네일 선택', 'thumbnail', enabled: widget.mediaTitle != null),
      OutlinedButton(
        onPressed: widget.mediaTitle == null ? null : widget.external,
        child: const Text('선택 파일 외부 앱으로 열기'),
      ),
    ]),
  ];
  List<Widget> get backupSettings => [
    section(
      '카탈로그와 기록 백업',
      '평점·배우·태그·이어보기·장면 메모·컬렉션·이동 규칙을 함께 보관합니다. 원본 영상 파일은 백업에 포함되지 않습니다.',
      [
        FilledButton.icon(
          onPressed: widget.backup,
          icon: const Icon(Icons.save_alt, size: 17),
          label: const Text('백업 · 내보내기'),
        ),
      ],
    ),
    section('백업 복원', '저장한 백업으로 카탈로그를 복원합니다. 복원 전 현재 기록의 백업을 자동으로 남깁니다.', [
      OutlinedButton(onPressed: widget.restore, child: const Text('백업 복원')),
    ]),
  ];

  List<Widget> get shortcutSettings => [
    Row(
      children: [
        const Expanded(
          child: Text(
            '키를 클릭해 변경하세요. 변경 내용은 자동 저장됩니다.',
            style: TextStyle(fontSize: 14, color: DeckDesign.muted),
          ),
        ),
        OutlinedButton(
          onPressed: () async {
            widget.keys.values = KeyBindings.defaults();
            await widget.keys.save();
            if (mounted) setState(() {});
          },
          child: const Text('기본값'),
        ),
      ],
    ),
    const SizedBox(height: 16),
    Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DeckDesign.surface,
        border: Border.all(color: DeckDesign.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const KeyCap('Esc'),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('소리를 끄고, 바로 최소화', style: TextStyle(fontSize: 14)),
                SizedBox(height: 9),
                Text(
                  '볼륨을 0%로 만든 뒤 창을 최소화합니다. 다시 열어도 소리는 켜지지 않아요.',
                  style: TextStyle(fontSize: 14, color: DeckDesign.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: DeckDesign.surface,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              '고정 단축키',
              style: TextStyle(fontSize: 14, color: DeckDesign.accent),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 26),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'PRESET',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1.5,
            color: DeckDesign.muted,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: managePresets,
            child: const Text('표준 + 왼손 보조'),
          ),
        ),
        const Text(
          '키를 클릭하고 새 조합을 눌러보세요',
          style: TextStyle(fontSize: 14, color: DeckDesign.muted),
        ),
      ],
    ),
    const SizedBox(height: 8),
    const SizedBox(
      height: 42,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 17),
        child: Row(
          children: [
            Expanded(
              flex: 42,
              child: Text(
                '기능',
                style: TextStyle(fontSize: 14, color: DeckDesign.muted),
              ),
            ),
            Expanded(
              flex: 29,
              child: Text(
                '기본키',
                style: TextStyle(fontSize: 14, color: DeckDesign.muted),
              ),
            ),
            Expanded(
              flex: 27,
              child: Text(
                '보조키',
                style: TextStyle(fontSize: 14, color: DeckDesign.muted),
              ),
            ),
          ],
        ),
      ),
    ),
    Container(
      height: 54,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 17),
      alignment: Alignment.centerLeft,
      color: const Color(0xff1b2a37),
      child: const Text(
        '재생 조작',
        style: TextStyle(fontSize: 14, color: DeckDesign.muted),
      ),
    ),
    for (final command in [
      'pause',
      'mute',
      ...KeyBindings.labels.keys.where(
        (key) => key != 'pause' && key != 'mute',
      ),
    ])
      Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 17),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xff2f4456))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 42,
              child: Text(
                KeyBindings.labels[command]!,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            for (var slot = 0; slot < 2; slot++)
              Expanded(
                flex: slot == 0 ? 29 : 27,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: keyButton(command, slot),
                ),
              ),
          ],
        ),
      ),
  ];

  static const sections = [
    '라이브러리',
    '재생',
    '단축키',
    '메타데이터',
    '사생활 보호',
    '백업',
    '앱 정보 · 업데이트',
  ];
  @override
  Widget build(BuildContext context) => SettingsTheme(
    child: LayoutBuilder(
      builder: (context, bounds) {
        final padding = bounds.maxWidth < 1200 ? 24.0 : 32.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '설정',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.close,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('영상으로 돌아가기'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: DeckDesign.line),
            if (bounds.maxWidth < 760)
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: tab,
                  decoration: const InputDecoration(labelText: '설정 카테고리'),
                  items: [
                    for (final name in sections)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => tab = value);
                  },
                ),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (bounds.maxWidth >= 760)
                    Container(
                      width: 224,
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: DeckDesign.line),
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final name in sections)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                key: ValueKey('settings-section-$name'),
                                minTileHeight: 56,
                                leading: Icon(switch (name) {
                                  '라이브러리' => Icons.video_library_outlined,
                                  '재생' => Icons.play_circle_outline,
                                  '메타데이터' => Icons.edit_note,
                                  '단축키' => Icons.keyboard_outlined,
                                  '사생활 보호' => Icons.lock_outline,
                                  '백업' => Icons.backup_outlined,
                                  _ => Icons.info_outline,
                                }, size: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                title: Text(
                                  name == '앱 정보 · 업데이트' ? '정보·업데이트' : name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: tab == name
                                        ? DeckDesign.text
                                        : DeckDesign.muted,
                                  ),
                                ),
                                selected: tab == name,
                                selectedTileColor: DeckDesign.surface,
                                onTap: () => setState(() => tab = name),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 944),
                        child: IndexedStack(
                          index: tab == '메타데이터' ? 0 : 1,
                          children: [
                            MetadataWorkspace(
                              library: widget.keys.library,
                              action: widget.action,
                              hasMedia: widget.mediaTitle != null,
                              onApplied: widget.metadataChanged,
                            ),
                            SingleChildScrollView(
                              key: PageStorageKey('settings-body-$tab'),
                              padding: EdgeInsets.all(padding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: Text(
                                      tab,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  ...switch (tab) {
                                    '재생' => playbackSettings,
                                    '단축키' => [
                                      SettingsSection(
                                        title: '키보드 단축키',
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: shortcutSettings,
                                          ),
                                        ],
                                      ),
                                    ],
                                    '사생활 보호' => [
                                      SettingsSection(
                                        title: '앱 접근 보호',
                                        children: [
                                          PrivacySettings(
                                            privacy: widget.privacy,
                                            lockNow: widget.lockNow,
                                          ),
                                        ],
                                      ),
                                    ],
                                    '백업' => backupSettings,
                                    '앱 정보 · 업데이트' => [
                                      UpdateSettings(
                                        install: widget.installUpdate,
                                      ),
                                    ],
                                    _ => librarySettings,
                                  },
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
