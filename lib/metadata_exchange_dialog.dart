import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'library.dart';
import 'metadata_exchange.dart';

class MetadataExchangeDialog extends StatefulWidget {
  final Library library;
  const MetadataExchangeDialog({super.key, required this.library});
  @override
  State<MetadataExchangeDialog> createState() => _MetadataExchangeDialogState();
}

class _MetadataExchangeDialogState extends State<MetadataExchangeDialog> {
  late final service = MetadataExchange(widget.library);
  final input = TextEditingController();
  Map<String, dynamic>? request;
  MetadataProposal? proposal;
  final selection = <int, Set<String>>{};
  bool busy = false;
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
    });
    try {
      await work();
    } catch (e) {
      if (mounted) message = e.toString();
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
    message = '복사했습니다. 외부 AI에 붙여넣어 주세요.';
  });
  void compare() => run(() async {
    invalidate();
    if (request == null) throw StateError('먼저 전체 정보를 내보내 주세요.');
    proposal = service.parse(input.text, request!);
    for (final entry in proposal!.changes.entries) {
      selection[entry.key] = entry.value.keys.toSet();
    }
  });
  int get chosen =>
      selection.values.fold(0, (sum, value) => sum + value.length);
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: DefaultTabController(
      length: 2,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 980,
          height: 760,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '영상정보 내보내기·입력하기',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    IconButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: '닫기',
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: '내보내기'),
                  Tab(text: '입력하기'),
                ],
              ),
              if (busy) const LinearProgressIndicator(),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(message!),
                ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: busy,
                  child: TabBarView(children: [exportPanel(), importPanel()]),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget exportPanel() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '라이브러리 전체 영상',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          '검색·필터·체크 여부와 관계없이 모든 영상의 파일명·제목·배우·태그·설명을 내보냅니다.\n영상 파일, 전체 경로, 개인 메모, 평점과 재생 기록은 포함하지 않습니다.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => copy(true),
              icon: const Icon(Icons.copy),
              label: const Text('AI 요청문 + 전체 정보 복사'),
            ),
            OutlinedButton(
              onPressed: () => run(() async {
                await ensureRequest();
                final location = await getSaveLocation(
                  suggestedName: 'soft-vault-metadata.json',
                  acceptedTypeGroups: [
                    const XTypeGroup(label: 'JSON', extensions: ['json']),
                  ],
                );
                if (location != null) {
                  await File(
                    location.path,
                  ).writeAsString(service.encode(request!), flush: true);
                  message = '전체 정보를 저장했습니다. 요청문과 함께 AI에 전달해 주세요.';
                }
              }),
              child: const Text('전체 정보 JSON 저장'),
            ),
            TextButton(
              onPressed: () => copy(false),
              child: const Text('요청문만 복사'),
            ),
          ],
        ),
        TextButton(
          child: const Text('사용 가이드와 복사용 요청문 보기'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('AI에 전달하는 방법'),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          '① 전체 정보와 요청문을 복사해 AI에 전달합니다. 큰 자료는 JSON 파일로 첨부합니다.\n② AI가 반환한 전체 JSON을 입력하기 탭에 붙여넣습니다.\n③ 변경 내용을 비교하고 적용할 필드를 선택합니다.',
                        ),
                      ),
                      SizedBox(
                        height: 150,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: const SelectableText(MetadataExchange.guide),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Clipboard.setData(
                    const ClipboardData(text: MetadataExchange.guide),
                  ),
                  child: const Text('요청문 복사'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                request == null
                    ? '아직 내보낸 요청이 없습니다.'
                    : '보관된 요청: ${(request!['rows'] as List).length}개 영상 · ${request!['created']}',
              ),
            ),
            TextButton(
              onPressed: () => run(() async {
                request = await service.create();
                invalidate();
                input.clear();
                message = '현재 전체 정보로 새 요청을 만들었습니다. 이전 요청의 결과는 적용할 수 없습니다.';
              }),
              child: const Text('현재 정보로 새 요청 만들기'),
            ),
          ],
        ),
        const Text(
          '복사·저장은 보관된 요청을 사용합니다. 새 요청을 만들면 이전 요청을 대체합니다.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: request == null
              ? const Center(child: Text('내보내기를 누르면 대상 정보가 표시됩니다.'))
              : ListView.builder(
                  itemCount: (request!['rows'] as List).length,
                  itemBuilder: (_, index) {
                    final row = request!['rows'][index];
                    return ListTile(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('${row['filename']}'),
                          content: SizedBox(
                            width: 600,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                [
                                  for (final f in MetadataExchange.fields)
                                    '${labels[f]}: ${row[f]}',
                                ].join('\n\n'),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('닫기'),
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        '${row['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${row['filename']} · ${row['actors']} · ${row['tags']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Widget importPanel() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI의 전체 결과 JSON을 입력하세요. 누락·빈 값은 기존 정보를 지우지 않습니다.'),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: TextField(
            controller: input,
            expands: true,
            maxLines: null,
            onChanged: (_) => setState(invalidate),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '전체 결과 JSON 붙여넣기',
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => run(() async {
                final value = await Clipboard.getData(Clipboard.kTextPlain);
                input.text = value?.text ?? '';
                invalidate();
              }),
              child: const Text('결과 붙여넣기'),
            ),
            TextButton(
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
              child: const Text('JSON 파일 열기'),
            ),
            FilledButton(onPressed: compare, child: const Text('변경 비교')),
          ],
        ),
        if (proposal != null) ...[
          Text(
            '변경 제안 ${proposal!.changes.length}개 영상 · 누락 ${proposal!.missing}개 영상은 유지 · 선택 $chosen개 필드',
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  for (final e in proposal!.changes.entries) {
                    selection[e.key] = e.value.keys.toSet();
                  }
                }),
                child: const Text('모두 선택'),
              ),
              TextButton(
                onPressed: () => setState(selection.clear),
                child: const Text('모두 해제'),
              ),
            ],
          ),
        ],
        Expanded(
          child: proposal == null
              ? const Center(child: Text('변경 비교를 누르면 현재 값과 AI 제안을 확인할 수 있습니다.'))
              : ListView.builder(
                  itemCount: proposal!.changes.length,
                  itemBuilder: (_, index) {
                    final e = proposal!.changes.entries.elementAt(index);
                    final old = (request!['rows'] as List).firstWhere(
                      (r) => r['id'] == e.key,
                    );
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${old['title']} · ${old['filename']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            for (final field in e.value.entries)
                              CheckboxListTile(
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                value:
                                    selection[e.key]?.contains(field.key) ??
                                    false,
                                onChanged: (value) => setState(() {
                                  final set = selection.putIfAbsent(
                                    e.key,
                                    () => {},
                                  );
                                  if (value == true) {
                                    set.add(field.key);
                                  } else {
                                    set.remove(field.key);
                                  }
                                }),
                                title: Text(labels[field.key]!),
                                subtitle: Text(
                                  '현재: ${old[field.key] == '' ? '비어 있음' : old[field.key]}\n제안: ${field.value}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                '적용 전 자동 백업을 만들고 선택한 변경만 한 번에 저장합니다.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            FilledButton(
              onPressed: proposal == null || chosen == 0
                  ? null
                  : () => run(() async {
                      await service.apply(proposal!, selection);
                      if (mounted) Navigator.pop(context, true);
                    }),
              child: const Text('선택한 변경 일괄 적용'),
            ),
          ],
        ),
      ],
    ),
  );
}
