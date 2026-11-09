import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design.dart';
import 'library_filter.dart';
import 'settings_components.dart';

class LibraryFilterDialog extends StatefulWidget {
  final LibraryFilter initial;
  final List<Map<String, Object?>> actors, tags;
  final Future<LibraryFilter> Function(LibraryFilter)? validate;
  const LibraryFilterDialog({
    super.key,
    required this.initial,
    required this.actors,
    required this.tags,
    this.validate,
  });
  @override
  State<LibraryFilterDialog> createState() => _LibraryFilterDialogState();
}

class _LibraryFilterDialogState extends State<LibraryFilterDialog> {
  late PlaybackFilter playback = widget.initial.playback;
  late int? rating = widget.initial.rating;
  late bool exact = widget.initial.exact,
      unrated = widget.initial.unrated,
      actorsAll = widget.initial.actorsAll,
      tagsAll = widget.initial.tagsAll;
  late Set<int> actors = widget.initial.actorIds.toSet(),
      tags = widget.initial.tagIds.toSet();
  String? notice;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final count = actors.length + tags.length;
    actors.retainAll(widget.actors.map((e) => e['id'] as int));
    tags.retainAll(widget.tags.map((e) => e['id'] as int));
    if (count != actors.length + tags.length)
      notice = '삭제된 배우·태그를 선택 조건에서 제외했습니다.';
  }

  LibraryFilter get draft => LibraryFilter(
    playback: playback,
    rating: unrated ? null : rating,
    unrated: unrated,
    exact: exact,
    actorIds: actors,
    tagIds: tags,
    actorsAll: actorsAll,
    tagsAll: tagsAll,
  );
  void reset() => setState(() {
    playback = PlaybackFilter.all;
    rating = null;
    exact = false;
    unrated = false;
    actors.clear();
    tags.clear();
    actorsAll = false;
    tagsAll = true;
    notice = null;
  });
  Future<void> apply() async {
    setState(() => saving = true);
    try {
      final before = draft, after = await widget.validate?.call(draft) ?? draft;
      if (!mounted) return;
      if (before.actorIds.length != after.actorIds.length ||
          before.tagIds.length != after.tagIds.length) {
        setState(() {
          actors = after.actorIds.toSet();
          tags = after.tagIds.toSet();
          notice = '삭제된 항목을 제외했습니다. 조건을 확인한 후 다시 적용해 주세요.';
        });
        return;
      }
      Navigator.pop(context, after);
    } catch (_) {
      if (mounted) setState(() => notice = '필터를 확인하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget entities(bool actor) => EntityFilterPanel(
    key: ValueKey(actor ? 'actor-filter' : 'tag-filter'),
    title: actor ? '배우' : '태그',
    entries: actor ? widget.actors : widget.tags,
    selected: actor ? actors : tags,
    all: actor ? actorsAll : tagsAll,
    onMode: (value) => setState(() {
      if (actor) {
        actorsAll = value;
      } else {
        tagsAll = value;
      }
    }),
    onToggle: (id) => setState(() {
      final values = actor ? actors : tags;
      if (!values.add(id)) values.remove(id);
    }),
    onClear: () => setState(() => (actor ? actors : tags).clear()),
  );
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SettingsTheme(
        child: SizedBox(
          width: math.min(960, size.width - 48),
          height: math.min(760, size.height - 48),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '라이브러리 필터',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '필터 닫기',
                      onPressed: saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: DeckDesign.line),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notice != null) SettingsStatus(notice!),
                      SettingsSection(
                        title: '재생 여부',
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final value in PlaybackFilter.values)
                                  ChoiceChip(
                                    key: ValueKey(
                                      'filter-playback-${value.name}',
                                    ),
                                    label: Text(value.label),
                                    selected: playback == value,
                                    onSelected: (_) =>
                                        setState(() => playback = value),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SettingsSection(
                        title: '평점',
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('전체'),
                                  selected: rating == null && !unrated,
                                  onSelected: (_) => setState(() {
                                    rating = null;
                                    unrated = false;
                                  }),
                                ),
                                ChoiceChip(
                                  label: const Text('별점 지정'),
                                  selected: rating != null,
                                  onSelected: (_) => setState(() {
                                    rating ??= 1;
                                    unrated = false;
                                  }),
                                ),
                                ChoiceChip(
                                  label: const Text('미평가'),
                                  selected: unrated,
                                  onSelected: (_) => setState(() {
                                    rating = null;
                                    unrated = true;
                                  }),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 1; i <= 5; i++)
                                    IconButton(
                                      key: ValueKey('filter-star-$i'),
                                      tooltip: '$i점 선택',
                                      isSelected:
                                          rating != null && i <= rating!,
                                      onPressed: () => setState(() {
                                        rating = i;
                                        unrated = false;
                                      }),
                                      icon: Icon(
                                        rating != null && i <= rating!
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: DeckDesign.gold,
                                        size: 28,
                                      ),
                                    ),
                                ],
                              ),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('이상'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('정확히'),
                                  ),
                                ],
                                selected: {exact},
                                onSelectionChanged: rating == null
                                    ? null
                                    : (value) =>
                                          setState(() => exact = value.single),
                              ),
                              Text(
                                draft.ratingLabel,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      LayoutBuilder(
                        builder: (context, bounds) => bounds.maxWidth < 752
                            ? Column(
                                children: [
                                  entities(true),
                                  const SizedBox(height: 16),
                                  entities(false),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: entities(true)),
                                  const SizedBox(width: 20),
                                  Expanded(child: entities(false)),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: DeckDesign.line),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: saving ? null : reset,
                      child: const Text('필터 초기화'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: saving ? null : apply,
                      child: Text(saving ? '확인 중…' : '적용'),
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

class EntityFilterPanel extends StatefulWidget {
  final String title;
  final List<Map<String, Object?>> entries;
  final Set<int> selected;
  final bool all;
  final ValueChanged<bool> onMode;
  final ValueChanged<int> onToggle;
  final VoidCallback onClear;
  const EntityFilterPanel({
    super.key,
    required this.title,
    required this.entries,
    required this.selected,
    required this.all,
    required this.onMode,
    required this.onToggle,
    required this.onClear,
  });
  @override
  State<EntityFilterPanel> createState() => _EntityFilterPanelState();
}

class _EntityFilterPanelState extends State<EntityFilterPanel> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final shown = widget.entries
        .where(
          (e) => '${e['name']} ${e['alias'] ?? ''}'.toLowerCase().contains(
            query.trim().toLowerCase(),
          ),
        )
        .toList();
    final chosen = widget.entries
        .where((e) => widget.selected.contains(e['id']))
        .toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DeckDesign.sidebar,
        border: Border.all(color: DeckDesign.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.title} · ${widget.selected.length}개 선택',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.selected.isEmpty ? null : widget.onClear,
                child: const Text('초기화'),
              ),
            ],
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('하나라도 포함')),
              ButtonSegment(value: true, label: Text('모두 포함')),
            ],
            selected: {widget.all},
            onSelectionChanged: (v) => widget.onMode(v.single),
          ),
          const SizedBox(height: 12),
          TextField(
            key: ValueKey('${widget.title}-search'),
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: widget.title == '배우' ? '배우 이름·별칭 검색' : '태그 이름 검색',
            ),
          ),
          if (chosen.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 88),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final e in chosen.take(12))
                        InputChip(
                          label: SizedBox(
                            width: 160,
                            child: Text(
                              e['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onDeleted: () => widget.onToggle(e['id'] as int),
                        ),
                      if (chosen.length > 12) Text('외 ${chosen.length - 12}개'),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      widget.entries.isEmpty
                          ? '등록된 ${widget.title}가 없습니다.'
                          : '검색 결과가 없습니다.',
                      style: const TextStyle(color: DeckDesign.muted),
                    ),
                  )
                : ListView.builder(
                    key: ValueKey('${widget.title}-choices'),
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final item = shown[index];
                      return Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          key: ValueKey('${widget.title}-${item['id']}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: widget.selected.contains(item['id']),
                          onChanged: (_) => widget.onToggle(item['id'] as int),
                          title: Text(
                            item['name'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: (item['alias'] as String? ?? '').isEmpty
                              ? null
                              : Text(
                                  item['alias'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
