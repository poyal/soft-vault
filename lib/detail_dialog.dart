import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'design.dart';
import 'playback_history.dart';
import 'file_list.dart';

class DetailEditor extends StatefulWidget {
  final Map<String, Object?> item;
  final VoidCallback play, rename, external, relink;
  final bool initiallyEditing;
  final Future<void> Function(int?)? onRating;
  final Future<void> Function(String)? onTags;
  final Future<List<Map<String, Object?>>> Function()? loadTags;
  const DetailEditor({
    super.key,
    required this.item,
    required this.play,
    required this.rename,
    required this.external,
    required this.relink,
    this.initiallyEditing = false,
    this.onRating,
    this.onTags,
    this.loadTags,
  });
  @override
  State<DetailEditor> createState() => _DetailEditorState();
}

class _DetailEditorState extends State<DetailEditor> {
  late bool editing = widget.initiallyEditing;
  bool savingRating = false;
  late final fields = {
    for (final key in ['title', 'actors', 'tags', 'description', 'note'])
      key: TextEditingController(text: widget.item[key] as String? ?? ''),
  };
  late int? rating = widget.item['rating'] as int?;
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> changeRating(int? value) async {
    if (savingRating) return;
    setState(() => savingRating = true);
    try {
      await widget.onRating?.call(value);
      if (mounted) setState(() => rating = value);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('평점 저장 실패: $e')));
    } finally {
      if (mounted) setState(() => savingRating = false);
    }
  }

  Future<void> chooseTags() async {
    final entries = await widget.loadTags!();
    if (!mounted) return;
    final selected = fields['tags']!.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final query = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('태그 지정'),
          content: SizedBox(
            width: 480,
            height: 360,
            child: Column(
              children: [
                TextField(
                  controller: query,
                  decoration: const InputDecoration(labelText: '태그 검색 또는 새 태그'),
                  onChanged: (_) => update(() {}),
                ),
                if (query.text.trim().isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        update(() => selected.add(query.text.trim())),
                    child: Text('“${query.text.trim()}” 추가'),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final name
                          in {
                            ...entries.map((e) => e['name'] as String),
                            ...selected,
                          }.where(
                            (s) => s.toLowerCase().contains(
                              query.text.trim().toLowerCase(),
                            ),
                          ))
                        CheckboxListTile(
                          title: Text(name),
                          value: selected.contains(name),
                          onChanged: (checked) => update(() {
                            if (checked == true)
                              selected.add(name);
                            else
                              selected.remove(name);
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected.join(', ')),
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
    // The closing dialog may still render during its reverse transition.
    if (result == null || !mounted) return;
    try {
      if (!editing) await widget.onTags?.call(result);
      if (mounted) setState(() => fields['tags']!.text = result);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('태그 저장 실패: $e')));
    }
  }

  Widget field(String key, String label, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: DeckDesign.muted),
        ),
        const SizedBox(height: 8),
        if (!editing)
          SelectableText(
            fields[key]!.text.isEmpty ? '—' : fields[key]!.text,
            style: const TextStyle(fontSize: 16, height: 1.5),
          )
        else
          TextField(
            style: const TextStyle(fontSize: 16, height: 1.5),
            controller: fields[key],
            autofocus: key == 'title',
            maxLines: lines,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: const Color(0xff14232d),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xff3b5366)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xff3b5366)),
              ),
            ),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final thumbnail = item['thumbnail'] as String? ?? '';
    return Dialog(
      backgroundColor: const Color(0xff1d2934),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xff3b5366)),
      ),
      child: SizedBox(
        width: 940,
        height: math.min(MediaQuery.sizeOf(context).height - 80, 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '상세정보',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '영상 정보와 기록을 확인하세요.',
                          style: TextStyle(
                            fontSize: 14,
                            color: DeckDesign.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: '닫기',
                    icon: const DesignIcon('close', size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xff323d49)),
            Expanded(
              child: _DetailColumns(
                children: [
                  Expanded(
                    flex: 48,
                    child: ColoredBox(
                      color: const Color(0xff18232d),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 10,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: thumbnail.isEmpty
                                    ? const ColoredBox(
                                        color: Color(0xff14232d),
                                        child: Icon(
                                          Icons.movie_outlined,
                                          size: 64,
                                        ),
                                      )
                                    : Image.file(
                                        File(thumbnail),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              displayTitle(item),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item['path'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                color: DeckDesign.muted,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.play();
                                },
                                icon: const Icon(
                                  Icons.play_arrow_outlined,
                                  size: 16,
                                ),
                                label: const Text('재생 화면 열기'),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 30,
                              runSpacing: 20,
                              children: [
                                for (final entry in {
                                  '폴더': p.basename(item['folder'] as String),
                                  '크기':
                                      '${((item['size'] as int? ?? 0) / 1048576).toStringAsFixed(2)} MB',
                                  '해상도': '${item['resolution'] ?? ''}',
                                  '코덱': '${item['codec'] ?? ''}',
                                  '재생 횟수': '${item['play_count'] ?? 0}회',
                                  '시청 상태': item['watched'] == 1
                                      ? '시청 완료'
                                      : ((item['play_count'] as int? ?? 0) > 0
                                            ? '재생한 적 있음'
                                            : '미재생'),
                                  '이어보기':
                                      '${((item['resume_ms'] as int? ?? 0) / 60000).floor()}분 ${(((item['resume_ms'] as int? ?? 0) / 1000).floor() % 60)}초',
                                  '최근 재생': formatPlaybackDate(
                                    item['last_played'] as int? ?? 0,
                                  ),
                                }.entries)
                                  SizedBox(
                                    width: 160,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: DeckDesign.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          entry.value,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            const Divider(color: Color(0xff323d49)),
                            const SizedBox(height: 18),
                            const Text(
                              '파일을 다른 연결 폴더로 옮겨도\n평점과 기록은 그대로 따라갑니다.',
                              style: TextStyle(
                                fontSize: 14,
                                color: DeckDesign.muted,
                                height: 1.8,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.rename();
                                  },
                                  child: const Text('이름 변경'),
                                ),
                                OutlinedButton(
                                  onPressed: widget.external,
                                  child: const Text('외부 앱으로 열기'),
                                ),
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.relink();
                                  },
                                  child: const Text('파일 재연결'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xff323d49)),
                  Expanded(
                    flex: 46,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (editing) field('title', '제목'),
                          const Text(
                            '평점',
                            style: TextStyle(
                              fontSize: 14,
                              color: DeckDesign.muted,
                            ),
                          ),
                          Row(
                            children: [
                              DeckStars(
                                rating: rating,
                                change: savingRating ? null : changeRating,
                                size: 23,
                                gap: 9,
                              ),
                              if (editing || widget.onRating != null)
                                TextButton(
                                  onPressed: savingRating
                                      ? null
                                      : () => changeRating(null),
                                  child: const Text('초기화'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          field('actors', editing ? '배우 · 쉼표로 구분' : '배우'),
                          Row(
                            children: [
                              const Expanded(child: Text('태그')),
                              if (widget.loadTags != null)
                                TextButton(
                                  onPressed: chooseTags,
                                  child: const Text('태그 지정'),
                                ),
                            ],
                          ),
                          if (editing) field('tags', '태그 · 쉼표로 구분'),
                          if (fields['tags']!.text.trim().isEmpty)
                            const Text('지정된 태그 없음'),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: fields['tags']!,
                            builder: (_, value, _) => Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  for (final tag
                                      in value.text
                                          .split(',')
                                          .map((s) => s.trim())
                                          .where((s) => s.isNotEmpty))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xff20394c),
                                        border: Border.all(
                                          color: const Color(0xff3c5d75),
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xffa0c4df),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          field('description', '설명 · 메모', lines: 4),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text(
                              '개인 메모',
                              style: TextStyle(
                                fontSize: 14,
                                color: DeckDesign.muted,
                              ),
                            ),
                            children: [field('note', '나만 보는 기록', lines: 2)],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xff323d49)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      editing
                          ? '변경 내용은 이 기기에 저장됩니다.'
                          : '정보 편집을 눌러 기록을 수정할 수 있습니다.',
                      style: TextStyle(fontSize: 14, color: DeckDesign.muted),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(editing ? '취소' : '닫기'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: !editing
                        ? () => setState(() => editing = true)
                        : () => Navigator.pop(context, <String, Object?>{
                            ...fields.map(
                              (key, value) => MapEntry(key, value.text),
                            ),
                            if (widget.onRating == null) 'rating': rating,
                          }),
                    child: Text(editing ? '저장' : '정보 편집'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailColumns extends StatelessWidget {
  final List<Widget> children;
  const _DetailColumns({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => bounds.maxWidth >= 800
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in children)
                  if (child is Expanded)
                    child.child
                  else
                    const Divider(height: 1),
              ],
            ),
          ),
  );
}
