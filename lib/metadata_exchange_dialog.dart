import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'design.dart';
import 'settings_components.dart';
import 'library.dart';
import 'metadata_exchange.dart';
import 'metadata_actor_image.dart';

class MetadataExchangeDialog extends StatefulWidget {
  final Library library;
  final bool embedded;
  final VoidCallback? onApplied;
  const MetadataExchangeDialog({
    super.key,
    required this.library,
    this.embedded = false,
    this.onApplied,
  });
  @override
  State<MetadataExchangeDialog> createState() => _MetadataExchangeDialogState();
}

class _MetadataExchangeDialogState extends State<MetadataExchangeDialog> {
  late final service = MetadataExchange(widget.library);
  final input = TextEditingController();
  Map<String, dynamic>? request;
  MetadataProposal? proposal;
  final selection = <int, Set<String>>{};
  final selectedImages = <String>{};
  bool busy = false, failed = false;
  int step = 0, applied = 0, appliedImages = 0;
  String? message;
  static const labels = {
    'title': '제목',
    'actors': '배우',
    'tags': '태그',
    'description': '설명',
  };
  @override
  void initState() {
    super.initState();
    run(() async {
      request = await service.load();
    });
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() work) async {
    setState(() {
      busy = true;
      message = null;
      failed = false;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        message = e.toString();
        failed = true;
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> ensureRequest() async {
    request ??= await service.create();
  }

  void invalidate() {
    proposal = null;
    selection.clear();
    selectedImages.clear();
  }

  Future<void> copy(bool includeData) => run(() async {
    if (includeData) await ensureRequest();
    await Clipboard.setData(
      ClipboardData(
        text: includeData
            ? '${MetadataExchange.guide}\n\n${service.encode(request!)}'
            : MetadataExchange.guide,
      ),
    );
    message = '복사했습니다. 외부 AI에 전달한 뒤 결과 입력으로 이동하세요.';
  });
  void compare() => run(() async {
    invalidate();
    if (request == null) throw StateError('먼저 전체 정보를 내보내 주세요.');
    proposal = service.parse(input.text, request!);
    for (final entry in proposal!.changes.entries) {
      selection[entry.key] = entry.value.keys.toSet();
    }
    step = 2;
  });
  int get chosen =>
      selection.values.fold(0, (sum, value) => sum + value.length);
  Future<void> saveJson() => run(() async {
    await ensureRequest();
    final location = await getSaveLocation(
      suggestedName: 'soft-vault-metadata.json',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (location == null) return;
    await File(
      location.path,
    ).writeAsString(service.encode(request!), flush: true);
    message = '전체 정보를 저장했습니다. 요청문과 함께 AI에 전달해 주세요.';
  });
  void guide() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('AI에 전달하는 방법'),
      content: const SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: SelectableText(MetadataExchange.guide),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final body = SettingsTheme(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '영상정보 내보내기·입력하기',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: busy
                        ? null
                        : () => Navigator.pop(
                            context,
                            applied > 0 || appliedImages > 0,
                          ),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 4; i++)
                  Chip(
                    avatar: Icon(
                      i < step
                          ? Icons.check_circle
                          : i == step
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: i <= step ? DeckDesign.accent : DeckDesign.muted,
                    ),
                    label: Text(
                      '${i + 1} · ${['내보내기', '입력', '변경 검토', '완료'][i]}',
                    ),
                    backgroundColor: i == step
                        ? DeckDesign.surface
                        : DeckDesign.sidebar,
                    side: BorderSide(
                      color: i == step ? DeckDesign.accent : DeckDesign.line,
                    ),
                  ),
              ],
            ),
          ),
          if (busy) const LinearProgressIndicator(minHeight: 3),
          if (message != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DeckDesign.surface,
                border: Border.all(
                  color: failed ? Colors.orangeAccent : DeckDesign.accent,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      failed ? Icons.error_outline : Icons.check_circle_outline,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(message!)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: AbsorbPointer(
              absorbing: busy,
              child: step == 2
                  ? ListView.builder(
                      key: const ValueKey('metadata-review'),
                      padding: const EdgeInsets.all(20),
                      itemCount:
                          proposal!.changes.length +
                          proposal!.actorImages.length +
                          1,
                      itemBuilder: (_, index) => index == 0
                          ? reviewPanel()
                          : index > proposal!.changes.length
                          ? actorImageCard(
                              proposal!.actorImages[index -
                                  proposal!.changes.length -
                                  1],
                            )
                          : reviewCard(
                              proposal!.changes.entries.elementAt(index - 1),
                            ),
                    )
                  : SingleChildScrollView(
                      key: ValueKey('metadata-step-$step'),
                      padding: const EdgeInsets.all(20),
                      child: switch (step) {
                        0 => exportPanel(),
                        1 => inputPanel(),
                        2 => reviewPanel(),
                        _ => donePanel(),
                      },
                    ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AbsorbPointer(absorbing: busy, child: footer()),
          ),
        ],
      ),
    );
    return widget.embedded
        ? body
        : PopScope(
            canPop: !busy,
            child: Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: SizedBox(width: 980, height: 760, child: body),
            ),
          );
  }

  Widget exportPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '영상정보를 한 번에 보완하세요',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      const Text('전체 라이브러리 정보를 AI에 전달한 뒤, 돌아온 결과를 비교하고 원하는 변경만 저장합니다.'),
      const SizedBox(height: 8),
      const Text('배우 이미지도 함께 요청합니다. 반환된 이미지 주소는 변경 검토에서 미리 보고 선택해 등록할 수 있습니다.'),
      const SizedBox(height: 24),
      SettingsSection(
        title: '내보내는 정보',
        description: '검색·필터·체크 여부와 관계없이 모든 영상을 포함합니다.',
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('파일명 · 제목 · 배우 · 태그 · 설명'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '영상 파일·전체 경로·개인 메모·평점·재생 기록은 포함하지 않습니다.',
              style: TextStyle(fontSize: 14, color: DeckDesign.muted),
            ),
          ),
        ],
      ),
      SettingsSection(
        title: request == null ? '첫 요청을 준비합니다' : '보관된 요청을 이어서 사용합니다',
        description: request == null
            ? '아래 복사 버튼을 누르면 현재 정보로 요청을 만듭니다.'
            : '${(request!['rows'] as List).length}개 영상 · ${request!['created']}',
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: saveJson,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('전체 정보 JSON 저장'),
                ),
                PopupMenuButton<String>(
                  tooltip: '요청 도구',
                  onSelected: (value) {
                    if (value == 'guide') guide();
                    if (value == 'copy') copy(false);
                    if (value == 'new')
                      run(() async {
                        request = await service.create();
                        invalidate();
                        input.clear();
                        message = '새 요청을 만들었습니다. 이전 요청의 결과는 적용할 수 없습니다.';
                      });
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'guide',
                      child: Text('사용 가이드와 복사용 요청문 보기'),
                    ),
                    PopupMenuItem(value: 'copy', child: Text('요청문만 복사')),
                    PopupMenuItem(value: 'new', child: Text('현재 정보로 새 요청 만들기')),
                  ],
                  child: const Chip(
                    avatar: Icon(Icons.more_horiz, size: 20),
                    label: Text('요청 도구 ▾'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
  Widget inputPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'AI가 반환한 결과를 입력하세요',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text('전체 JSON을 붙여넣거나 파일로 불러오세요. 누락·빈 값은 기존 정보를 지우지 않습니다.'),
      const SizedBox(height: 8),
      const Text(
        '배우 이미지는 actorImages의 name·imageUrl로 받습니다. 이미지가 없는 결과도 그대로 사용할 수 있습니다.',
        style: TextStyle(fontSize: 14, color: DeckDesign.muted),
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.content_paste),
            label: const Text('결과 붙여넣기'),
            onPressed: () => run(() async {
              input.text =
                  (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
              invalidate();
            }),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('JSON 파일 열기'),
            onPressed: () => run(() async {
              final file = await openFile(
                acceptedTypeGroups: [
                  const XTypeGroup(label: 'JSON', extensions: ['json']),
                ],
              );
              if (file != null) {
                input.text = await file.readAsString();
                invalidate();
              }
            }),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        controller: input,
        minLines: 8,
        maxLines: 14,
        onChanged: (_) => setState(invalidate),
        decoration: const InputDecoration(
          labelText: '전체 결과 JSON',
          alignLabelWithHint: true,
          hintText: '전체 결과 JSON 붙여넣기',
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );
  Widget reviewPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '변경 제안 ${proposal!.changes.length}개 영상',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text('누락 ${proposal!.missing}개 영상은 유지합니다. 선택한 $chosen개 필드만 적용합니다.'),
      if (proposal!.actorImages.isNotEmpty)
        Text(
          '배우 이미지 ${proposal!.actorImages.length}개 · 선택 ${selectedImages.length}개. 이미지를 불러와 인물을 확인한 뒤 선택하세요.',
        ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => setState(() {
              for (final e in proposal!.changes.entries) {
                selection[e.key] = e.value.keys.toSet();
              }
            }),
            child: const Text('모두 선택'),
          ),
          OutlinedButton(
            onPressed: () => setState(() {
              selection.clear();
              selectedImages.clear();
            }),
            child: const Text('모두 해제'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (proposal!.changes.isEmpty && proposal!.actorImages.isEmpty)
        const SettingsSection(
          title: '변경할 내용이 없습니다',
          description: '입력한 결과가 현재 정보와 같습니다. 입력 단계로 돌아가 다른 결과를 확인할 수 있습니다.',
          children: [],
        ),
    ],
  );
  Widget actorImageCard(MetadataActorImage image) => SettingsSection(
    title: '${image.name} · 배우 이미지',
    description: image.previousImage.isEmpty
        ? '새 대표 이미지'
        : '선택하면 기존 대표 이미지를 교체합니다.',
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          if (image.previousImage.isNotEmpty)
            Column(
              children: [
                const Text('현재'),
                const SizedBox(height: 8),
                Image.file(
                  File(image.previousImage),
                  width: 120,
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 120,
                    height: 140,
                    child: Center(child: Text('이미지 없음')),
                  ),
                ),
              ],
            ),
          if (image.bytes != null)
            Column(
              children: [
                const Text('변경'),
                const SizedBox(height: 8),
                Image.memory(
                  image.bytes!,
                  width: 120,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ],
            ),
        ],
      ),
      const SizedBox(height: 12),
      SelectableText(
        image.imageUrl,
        style: const TextStyle(fontSize: 14, color: DeckDesign.muted),
      ),
      if (image.error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            image.error!,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        ),
      if (image.bytes == null)
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => run(() => service.loadActorImage(image)),
          icon: const Icon(Icons.image_outlined),
          label: Text(image.error == null ? '이미지 불러오기' : '다시 불러오기'),
        ),
      Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('이 배우 이미지 적용'),
          subtitle: const Text('배우가 새로 추가된다면 영상의 배우 정보도 함께 선택하세요.'),
          value: selectedImages.contains(image.name),
          onChanged: image.bytes == null
              ? null
              : (value) => setState(() {
                  if (value == true) {
                    selectedImages.add(image.name);
                  } else {
                    selectedImages.remove(image.name);
                  }
                }),
        ),
      ),
    ],
  );
  Widget reviewCard(MapEntry<int, Map<String, dynamic>> e) {
    final old = (request!['rows'] as List).firstWhere((r) => r['id'] == e.key);
    return SettingsSection(
      title: '${old['title']}',
      description: '${old['filename']}',
      children: [
        for (final field in e.value.entries)
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              value: selection[e.key]?.contains(field.key) ?? false,
              onChanged: (value) => setState(() {
                final set = selection.putIfAbsent(e.key, () => {});
                if (value == true) {
                  set.add(field.key);
                } else {
                  set.remove(field.key);
                }
              }),
              title: Text(
                labels[field.key]!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '현재  ${old[field.key] == '' ? '비어 있음' : old[field.key]}',
                      style: const TextStyle(color: DeckDesign.muted),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DeckDesign.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '변경  ${field.value}',
                        style: const TextStyle(color: DeckDesign.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget donePanel() => SettingsSection(
    title: '영상정보를 저장했습니다',
    description:
        '$applied개 필드와 배우 이미지 $appliedImages개를 적용했습니다. 적용 전 정보는 자동 백업으로 보관됩니다.',
    children: const [
      Padding(
        padding: EdgeInsets.all(24),
        child: Icon(
          Icons.check_circle_outline,
          color: DeckDesign.accent,
          size: 56,
        ),
      ),
    ],
  );
  Widget footer() => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 12,
    runSpacing: 12,
    children: [
      if (step == 0) ...[
        OutlinedButton.icon(
          onPressed: request == null || busy
              ? null
              : () => setState(() {
                  step = 1;
                  message = null;
                }),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('결과 입력으로 이동'),
        ),
        FilledButton.icon(
          onPressed: busy ? null : () => copy(true),
          icon: const Icon(Icons.copy),
          label: const Text('AI 요청문 + 전체 정보 복사'),
        ),
      ],
      if (step == 1) ...[
        OutlinedButton(
          onPressed: () => setState(() {
            step = 0;
            message = null;
          }),
          child: const Text('이전 · 내보내기'),
        ),
        FilledButton(
          onPressed: busy || input.text.trim().isEmpty ? null : compare,
          child: const Text('변경 비교'),
        ),
      ],
      if (step == 2) ...[
        OutlinedButton(
          onPressed: () => setState(() {
            step = 1;
            message = null;
          }),
          child: const Text('이전 · 입력 수정'),
        ),
        FilledButton(
          onPressed: busy || (chosen == 0 && selectedImages.isEmpty)
              ? null
              : () => run(() async {
                  final count = chosen;
                  final imageCount = selectedImages.length;
                  await service.apply(
                    proposal!,
                    selection,
                    selectedImages: selectedImages,
                  );
                  applied = count;
                  appliedImages = imageCount;
                  request = null;
                  input.clear();
                  invalidate();
                  step = 3;
                  if (mounted) widget.onApplied?.call();
                }),
          child: const Text('선택한 변경 일괄 적용'),
        ),
      ],
      if (step == 3)
        FilledButton(
          onPressed: () => setState(() {
            step = 0;
            message = null;
          }),
          child: const Text('새 작업 시작'),
        ),
    ],
  );
}
