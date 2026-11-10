import 'design.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'advanced_catalog.dart';
import 'criteria_dialog.dart';
import 'library.dart';
import 'rule_runner.dart';

class OrganizePanel extends StatefulWidget {
  final Library library;
  final RuleRunner rules;
  final ValueChanged<Map<String, Object?>> openCollection, openMedia;
  final Future<void> Function() prepare, changed;
  const OrganizePanel({
    super.key,
    required this.library,
    required this.rules,
    required this.openCollection,
    required this.openMedia,
    required this.prepare,
    required this.changed,
  });
  @override
  State<OrganizePanel> createState() => _OrganizePanelState();
}

class _OrganizePanelState extends State<OrganizePanel> {
  String tab = 'collections';
  List<Map<String, Object?>> rows = [];
  List<List<Map<String, Object?>>> duplicates = [];
  bool similar = false, loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final data = tab == 'rules'
          ? await widget.library.moveRules()
          : await widget.library.collections();
      final groups = tab == 'duplicates'
          ? await widget.library.duplicateGroups(similar: similar)
          : <List<Map<String, Object?>>>[];
      if (mounted)
        setState(() {
          rows = data;
          duplicates = groups;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, Object?>? row]) async {
    final folders = await widget.library.folders();
    if (!mounted) return;
    await showDeckDialog<bool>(
      context: context,
      builder: (_) => CriteriaDialog(
        name: row?['name'] as String? ?? '',
        initial: row == null
            ? const MediaCriteria()
            : MediaCriteria.decode(row['criteria'] as String),
        folders: folders,
        rule: tab == 'rules',
        destination: row?['destination'] as String?,
        automatic: row?['enabled'] == 1,
        autoRename: row?['auto_rename'] == 1,
        save: (draft) async {
          if (tab == 'rules') {
            await widget.library.saveMoveRule(
              draft.name,
              draft.criteria,
              draft.destination ?? '',
              id: row?['id'] as int?,
              enabled: draft.automatic,
              autoRename: draft.autoRename,
            );
          } else {
            await widget.library.saveCollection(
              draft.name,
              draft.criteria,
              id: row?['id'] as int?,
            );
          }
        },
      ),
    );
    await load();
    await widget.changed();
  }

  Future<void> remove(Map<String, Object?> row) async {
    final confirmed = await showDeckDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장한 조건 삭제'),
        content: Text('${row['name']} 조건을 삭제합니다. 미디어 파일은 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (tab == 'rules') {
      await widget.library.deleteMoveRule(row['id'] as int);
    } else {
      await widget.library.deleteCollection(row['id'] as int);
    }
    await load();
    await widget.changed();
  }

  Future<void> previewRule(Map<String, Object?> row) async {
    final candidates = await widget.rules.preview(row);
    if (!mounted) return;
    final run = await showDeckDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${row['name']} · 이동 검토'),
        content: SizedBox(
          width: 620,
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${candidates.length}개 파일 → ${row['destination']}'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: candidates
                      .map(
                        (item) => ListTile(
                          title: Text(item['title'] as String),
                          subtitle: Text(item['path'] as String),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Text('실행하면 실제 파일이 이동합니다. ID와 기록은 유지됩니다.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: candidates.isEmpty
                ? null
                : () => Navigator.pop(context, true),
            child: const Text('이동 실행'),
          ),
        ],
      ),
    );
    if (run != true) return;
    setState(() => loading = true);
    try {
      await widget.prepare();
      final previous = (await widget.rules.jobs.history())
          .map((job) => job['id'])
          .toSet();
      await widget.rules.run(row);
      await widget.changed();
      final results = (await widget.rules.jobs.history())
          .where((job) => !previous.contains(job['id']))
          .toList();
      final moved = results.where((job) => job['state'] == 'done').length;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '이동 $moved개 · 미완료 ${results.length - moved}개. 자세한 내용은 파일 작업 기록에서 확인하세요.',
            ),
          ),
        );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      await load();
    }
  }

  Widget thumbnail(Map<String, Object?> item) => Image.file(
    File(
      (item['thumbnail'] as String? ?? '').isNotEmpty
          ? item['thumbnail'] as String
          : item['path'] as String,
    ),
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => const Center(child: Icon(Icons.movie_outlined)),
  );
  Future<void> compare(List<Map<String, Object?>> group) async {
    var left = 0, right = 1;
    String? result;
    bool checking = false;
    await showDeckDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(similar ? '유사 후보 비교' : '동일 내용 파일 비교'),
          content: SizedBox(
            width: 900,
            height: 510,
            child: Column(
              children: [
                Text(
                  similar
                      ? '길이·해상도가 비슷한 후보입니다. 같은 영상이라고 확정하지 않습니다.'
                      : '내용 검사에서 같은 지문으로 확인된 파일입니다. 현재 내용을 다시 검증할 수 있습니다.',
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final side in [0, 1])
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: side == 0 ? 20 : 0),
                            child: Builder(
                              builder: (context) {
                                final item = group[side == 0 ? left : right];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DropdownButton<int>(
                                      value: side == 0 ? left : right,
                                      isExpanded: true,
                                      items: [
                                        for (var i = 0; i < group.length; i++)
                                          DropdownMenuItem(
                                            value: i,
                                            child: Text(
                                              '${i + 1}. ${group[i]['title']}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (value) => update(() {
                                        if (side == 0) {
                                          left = value!;
                                        } else {
                                          right = value!;
                                        }
                                        result = null;
                                      }),
                                    ),
                                    SizedBox(
                                      height: 180,
                                      width: double.infinity,
                                      child: thumbnail(item),
                                    ),
                                    const SizedBox(height: 12),
                                    SelectableText(
                                      item['path'] as String,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${item['size']} bytes · ${item['resolution']} · ${item['duration']}초',
                                    ),
                                    Text(
                                      '평점 ${item['rating'] ?? '미평가'} · ${item['tags']}',
                                    ),
                                    Text(
                                      item['note'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        widget.openMedia(item);
                                      },
                                      child: const Text('파일 보기'),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (result != null) Text(result!),
                if (checking) const LinearProgressIndicator(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: checking || left == right
                  ? null
                  : () async {
                      update(() => checking = true);
                      try {
                        final equal = await widget.library.verifyDuplicate(
                          group[left]['id'] as int,
                          group[right]['id'] as int,
                        );
                        update(
                          () => result = equal
                              ? '현재 파일 내용이 동일합니다.'
                              : '내용이 다르거나 오프라인입니다.',
                        );
                      } catch (e) {
                        update(() => result = '$e');
                      } finally {
                        if (context.mounted) update(() => checking = false);
                      }
                    },
              child: const Text('내용 재검증'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(36),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '라이브러리 정리',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            for (final entry in {
              'collections': '스마트 컬렉션',
              'duplicates': '중복 비교',
              'rules': '이동 규칙',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: tab == entry.key
                        ? const Color(0xff233b4e)
                        : null,
                  ),
                  onPressed: () {
                    setState(() => tab = entry.key);
                    load();
                  },
                  child: Text(entry.value),
                ),
              ),
            const Spacer(),
            if (tab != 'duplicates')
              FilledButton.icon(
                onPressed: loading ? null : () => edit(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(tab == 'rules' ? '규칙 추가' : '컬렉션 추가'),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.orange)),
        if (tab == 'duplicates')
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('길이·해상도가 비슷한 후보 포함'),
            value: similar,
            onChanged: (value) {
              setState(() => similar = value!);
              load();
            },
          ),
        if (loading) const LinearProgressIndicator(),
        Expanded(
          child: tab == 'duplicates'
              ? duplicates.isEmpty
                    ? const Center(child: Text('비교할 중복 후보가 없습니다.'))
                    : ListView(
                        children: duplicates
                            .map(
                              (group) => Card(
                                child: ListTile(
                                  leading: SizedBox(
                                    width: 78,
                                    height: 51,
                                    child: thumbnail(group.first),
                                  ),
                                  title: Text(
                                    '${group.first['title']} · ${group.length}개 위치',
                                  ),
                                  subtitle: Text(
                                    similar ? '유사 후보 · 직접 확인 필요' : '동일 SHA-256',
                                  ),
                                  trailing: const Icon(Icons.compare_outlined),
                                  onTap: () => compare(group),
                                ),
                              ),
                            )
                            .toList(),
                      )
              : rows.isEmpty
              ? Center(
                  child: Text(
                    tab == 'rules'
                        ? '출발 폴더와 조건을 지정해 이동 규칙을 만드세요.'
                        : '자주 찾는 조건을 저장하면 새 파일도 자동으로 모입니다.',
                  ),
                )
              : ListView(
                  children: rows
                      .map(
                        (row) => Card(
                          child: ListTile(
                            title: Text(
                              '${row['name']}${row['enabled'] == 1 ? ' · 자동' : ''}',
                            ),
                            subtitle: Text(
                              '${MediaCriteria.decode(row['criteria'] as String).summary}${tab == 'rules' ? ' → ${row['destination']}' : ''}',
                            ),
                            onTap: () => tab == 'rules'
                                ? previewRule(row)
                                : widget.openCollection(row),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => edit(row),
                                  tooltip: '조건 편집',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => remove(row),
                                  tooltip: '조건 삭제',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    ),
  );
}
