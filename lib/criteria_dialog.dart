import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'advanced_catalog.dart';

class CriteriaDraft {
  final String name;
  final MediaCriteria criteria;
  final String? destination;
  final bool automatic, autoRename;
  CriteriaDraft(
    this.name,
    this.criteria,
    this.destination,
    this.automatic,
    this.autoRename,
  );
}

class CriteriaDialog extends StatefulWidget {
  final String name;
  final MediaCriteria initial;
  final List<String> folders;
  final bool rule, automatic, autoRename;
  final String? destination;
  final Future<void> Function(CriteriaDraft) save;
  const CriteriaDialog({
    super.key,
    this.name = '',
    this.initial = const MediaCriteria(),
    required this.folders,
    this.rule = false,
    this.automatic = false,
    this.autoRename = false,
    this.destination,
    required this.save,
  });
  @override
  State<CriteriaDialog> createState() => _CriteriaDialogState();
}

class _CriteriaDialogState extends State<CriteriaDialog> {
  late final name = TextEditingController(text: widget.name),
      query = TextEditingController(text: widget.initial.query),
      tags = TextEditingController(text: widget.initial.tags),
      actor = TextEditingController(text: widget.initial.actor);
  late String? folder = widget.folders.contains(widget.initial.folder)
          ? widget.initial.folder
          : null,
      type = widget.initial.type == 'video' ? 'video' : null,
      destination = widget.folders.contains(widget.destination)
          ? widget.destination
          : null;
  late int? rating = widget.initial.minimumRating;
  late bool unrated = widget.initial.unrated,
      unfinished = widget.initial.unfinished,
      online = widget.initial.onlineOnly,
      automatic = widget.automatic,
      autoRename = widget.autoRename;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final controller in [name, query, tags, actor]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.rule ? '규칙 기반 이동' : '스마트 컬렉션'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '이름'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: query,
              decoration: const InputDecoration(
                labelText: '검색어',
                hintText: '제목, 파일명, 설명, 메모',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: tags,
                    decoration: const InputDecoration(
                      labelText: '모두 포함할 태그',
                      hintText: '쉼표로 구분',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: actor,
                    decoration: const InputDecoration(labelText: '배우 이름 또는 별칭'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: folder ?? '',
              isExpanded: true,
              decoration: InputDecoration(
                labelText: widget.rule ? '출발 폴더' : '폴더',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('모든 폴더')),
                ...widget.folders.map(
                  (root) => DropdownMenuItem(
                    value: root,
                    child: Text(
                      p.basename(root),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) =>
                  setState(() => folder = value == '' ? null : value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: rating ?? 0,
                    decoration: const InputDecoration(labelText: '평점'),
                    items: [
                      for (var i = 0; i <= 5; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(i == 0 ? '모든 평점' : '$i점 이상'),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => rating = value == 0 ? null : value),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('미평가만'),
              value: unrated,
              onChanged: (value) => setState(() => unrated = value!),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('이어볼 영상만'),
              value: unfinished,
              onChanged: (value) => setState(() => unfinished = value!),
            ),
            if (!widget.rule)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('온라인 파일만'),
                value: online,
                onChanged: (value) => setState(() => online = value!),
              ),
            if (widget.rule) ...[
              DropdownButtonFormField<String>(
                initialValue: destination,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '목적지 폴더'),
                items: widget.folders
                    .map(
                      (root) => DropdownMenuItem(
                        value: root,
                        child: Text(
                          p.basename(root),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => destination = value),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('스캔 후 자동 적용'),
                subtitle: const Text('끄면 이동 목록을 검토한 뒤 직접 실행합니다.'),
                value: automatic,
                onChanged: (value) => setState(() => automatic = value!),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('이름 충돌 시 자동 이름 변경'),
                subtitle: const Text('기본값은 건너뛰기입니다.'),
                value: autoRename,
                onChanged: (value) => setState(() => autoRename = value!),
              ),
            ],
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.orange)),
            if (saving) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  await widget.save(
                    CriteriaDraft(
                      name.text,
                      MediaCriteria(
                        query: query.text,
                        tags: tags.text,
                        actor: actor.text,
                        folder: folder,
                        type: type,
                        minimumRating: unrated ? null : rating,
                        unrated: unrated,
                        unfinished: unfinished,
                        onlineOnly: online,
                      ),
                      destination,
                      automatic,
                      autoRename,
                    ),
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (mounted) setState(() => error = '$e');
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
        child: const Text('저장'),
      ),
    ],
  );
}
