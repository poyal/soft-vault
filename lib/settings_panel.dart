import 'design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'key_bindings.dart';
import 'privacy_lock.dart';
import 'privacy_ui.dart';

class SettingsPanel extends StatefulWidget {
  final PrivacyLock? privacy;
  final Future<void> Function()? lockNow;
  final KeyBindings keys;
  final ValueChanged<bool> capturing;
  final VoidCallback backup, restore, external, connect, folders, close;
  final ValueChanged<String> action;
  final int folderCount;
  final String? mediaTitle;
  final bool busy;
  const SettingsPanel({
    super.key,
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
      await showDeckDialog<void>(
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
                TextButton(
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
    await showDeckDialog<void>(
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
            TextButton(
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
    return InkWell(
      onTap: () => capture(command, slot),
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: slot >= values.length
            ? const Text(
                '지정 안 됨',
                style: TextStyle(fontSize: 11, color: Color(0xff5f7485)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final key in chordLabel(values[slot]).split(' + '))
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: KeyCap(key),
                    ),
                ],
              ),
      ),
    );
  }

  Widget section(String title, String description, List<Widget> children) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xff1c2935),
          border: Border.all(color: DeckDesign.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                height: 1.7,
                color: DeckDesign.muted,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 10, children: children),
          ],
        ),
      );

  Widget action(String label, String id, {bool enabled = true}) =>
      OutlinedButton(
        onPressed: enabled && !widget.busy ? () => widget.action(id) : null,
        child: Text(label),
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
        action('다시 검색', 'rescan'),
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
    section('영상 메타데이터', '선택한 영상의 제목·배우·태그·평점을 NFO 파일과 주고받습니다.', [
      action('NFO 가져오기', 'nfoImport', enabled: widget.mediaTitle != null),
      action('NFO 내보내기', 'nfoExport', enabled: widget.mediaTitle != null),
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
            style: TextStyle(fontSize: 12, color: DeckDesign.muted),
          ),
        ),
        TextButton(
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
        color: const Color(0xff1e3a4e),
        border: Border.all(color: const Color(0xff45667e)),
        borderRadius: BorderRadius.circular(9),
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
                Text('소리를 끄고, 바로 최소화', style: TextStyle(fontSize: 12)),
                SizedBox(height: 9),
                Text(
                  '볼륨을 0%로 만든 뒤 창을 최소화합니다. 다시 열어도 소리는 켜지지 않아요.',
                  style: TextStyle(fontSize: 10, color: DeckDesign.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xff25352f),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              '고정 단축키',
              style: TextStyle(fontSize: 10, color: DeckDesign.accent),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 26),
    Row(
      children: [
        const Text(
          'PRESET',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.5,
            color: DeckDesign.muted,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 28,
          child: OutlinedButton(
            onPressed: managePresets,
            child: const Text('표준 + 왼손 보조', style: TextStyle(fontSize: 10)),
          ),
        ),
        const Spacer(),
        const Text(
          '키를 클릭하고 새 조합을 눌러보세요',
          style: TextStyle(fontSize: 11, color: DeckDesign.muted),
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
                style: TextStyle(fontSize: 10, color: DeckDesign.muted),
              ),
            ),
            Expanded(
              flex: 29,
              child: Text(
                '기본키',
                style: TextStyle(fontSize: 10, color: DeckDesign.muted),
              ),
            ),
            Expanded(
              flex: 27,
              child: Text(
                '보조키',
                style: TextStyle(fontSize: 10, color: DeckDesign.muted),
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
        style: TextStyle(fontSize: 11, color: DeckDesign.muted),
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
        height: 57,
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
                style: const TextStyle(fontSize: 12),
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Padding(
      padding: EdgeInsets.fromLTRB(
        bounds.maxWidth < 800 ? 28 : 48,
        28,
        bounds.maxWidth < 800 ? 28 : 48,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '설정',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: widget.close,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('영상으로 돌아가기'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '폴더, 재생, 단축키, 사생활 보호와 백업을 한곳에서 관리하세요.',
            style: TextStyle(fontSize: 12, color: DeckDesign.muted),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final name in ['라이브러리', '재생', '단축키', '사생활 보호', '백업'])
                ChoiceChip(
                  key: ValueKey('settings-section-$name'),
                  label: Text(name),
                  selected: tab == name,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => tab = name),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('settings-body-$tab'),
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: switch (tab) {
                  '사생활 보호' => [
                    PrivacySettings(
                      privacy: widget.privacy,
                      lockNow: widget.lockNow,
                    ),
                  ],
                  '재생' => playbackSettings,
                  '단축키' => shortcutSettings,
                  '백업' => backupSettings,
                  _ => librarySettings,
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
