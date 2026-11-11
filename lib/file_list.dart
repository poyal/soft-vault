import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'hover_preview.dart';
import 'design.dart';
import 'player_controls.dart';

class VaultFileList extends StatelessWidget {
  final List<Map<String, Object?>> items;
  final Set<int> selected;
  final int? current;
  final bool grid;
  final ValueChanged<int> toggle;
  final ValueChanged<Map<String, Object?>> preview, play;
  final Future<String> Function(Map<String, Object?>)? motionPreview;
  const VaultFileList({
    super.key,
    required this.items,
    required this.selected,
    required this.current,
    required this.grid,
    required this.toggle,
    required this.preview,
    required this.play,
    this.motionPreview,
  });
  Widget thumbnail(Map<String, Object?> item) {
    final path = (item['thumbnail'] as String? ?? '').isNotEmpty
        ? item['thumbnail'] as String
        : '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ColoredBox(
        color: const Color(0xff233b4e),
        child: path.isEmpty
            ? const Center(child: DesignIcon('film'))
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 480,
                errorBuilder: (_, _, _) =>
                    const Center(child: DesignIcon('image')),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (items.isEmpty)
        return const Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Text(
              '표시할 파일이 없습니다.',
              style: TextStyle(fontSize: 14, color: DeckDesign.muted),
            ),
          ),
        );
      final small = bounds.maxWidth <= 340;
      Widget tile(BuildContext context, int index) {
        final item = items[index], id = item['id'] as int;
        final isCurrent = current == id;
        final hasPlayed =
            (item['play_count'] as int? ?? 0) > 0 ||
            (item['last_played'] as int? ?? 0) > 0 ||
            (item['resume_ms'] as int? ?? 0) > 0 ||
            item['watched'] == 1;
        final playbackStatus = Tooltip(
          message: hasPlayed ? '재생한 적 있음' : '미재생',
          child: Semantics(
            label: hasPlayed ? '재생한 적 있음' : '미재생',
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xee14232d),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasPlayed
                    ? Icons.play_circle_filled
                    : Icons.play_circle_outline,
                key: ValueKey('file-playback-$id'),
                size: 16,
                color: hasPlayed ? DeckDesign.accent : DeckDesign.muted,
              ),
            ),
          ),
        );
        final actors = (item['actors'] as String? ?? '')
            .split(',')
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .join(' · ');
        final tags = (item['tags'] as String? ?? '')
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .map((tag) => '#$tag')
            .join(' · ');
        Widget metadata(
          String field,
          String icon,
          String title,
          String value,
          String empty,
        ) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Tooltip(
            message: '$title: ${value.isEmpty ? empty : value}',
            child: Row(
              children: [
                DesignIcon(icon, size: 10, color: const Color(0xff829bad)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    value.isEmpty ? empty : value,
                    key: ValueKey('file-$field-$id'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: value.isEmpty
                          ? const Color(0xffb3c1cd)
                          : const Color(0xff9eb9cc),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        final thumb = InkWell(
          onTap: () => play(item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              HoverPreview(
                key: ValueKey('$id:${item['modified']}'),
                load:
                    item['type'] == 'video' &&
                        item['online'] == 1 &&
                        motionPreview != null
                    ? () => motionPreview!(item)
                    : null,
                child: thumbnail(item),
              ),
              Positioned(left: 3, bottom: 3, child: playbackStatus),
            ],
          ),
        );
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: item['title'] as String,
              child: Text(
                item['title'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: DeckDesign.text,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${item['online'] == 0 ? '오프라인' : clockText(Duration(milliseconds: ((item['duration'] as num) * 1000).round()))} · ${p.basename(item['folder'] as String)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: isCurrent ? const Color(0xffb3c1cd) : DeckDesign.muted,
              ),
            ),
            const SizedBox(height: 3),
            DeckStars(rating: item['rating'] as int?, size: 10, gap: 1),
            metadata('actors', 'person', '배우', actors, '배우 미등록'),
            metadata('tags', 'tag', '태그', tags, '태그 없음'),
          ],
        );
        return _HoverTile(
          builder: (hovered) {
            final check = Semantics(
              checked: selected.contains(id),
              label: '${item['title']} 선택',
              child: Tooltip(
                message: '${item['title']} 선택',
                child: InkWell(
                  onTap: () => toggle(id),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: selected.contains(id)
                              ? DeckDesign.accent
                              : const Color(0xff18232e),
                          border: Border.all(color: const Color(0xff516b7e)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: selected.contains(id)
                            ? const DesignIcon(
                                'check',
                                size: 10,
                                color: Color(0xff183245),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            );
            return Draggable<List<int>>(
              data: selected.contains(id) ? selected.toList() : [id],
              feedback: Material(
                color: const Color(0xff283a49),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(item['title'] as String),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: selected.contains(id)
                      ? const Color(0xff30485b)
                      : isCurrent
                      ? const Color(0xff283a49)
                      : hovered
                      ? const Color(0xff25313c)
                      : DeckDesign.sidebar,
                  border: Border.all(
                    color: isCurrent ? DeckDesign.accent : DeckDesign.line,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Stack(
                  children: [
                    if (isCurrent)
                      const Positioned(
                        left: 0,
                        top: 8,
                        bottom: 8,
                        child: ColoredBox(
                          color: DeckDesign.accent,
                          child: SizedBox(width: 3),
                        ),
                      ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        focusColor: const Color(0x4487b8d8),
                        onTap: () => preview(item),
                        onDoubleTap: () => play(item),
                        borderRadius: BorderRadius.circular(7),
                        child: Padding(
                          padding: grid
                              ? const EdgeInsets.all(8)
                              : EdgeInsets.fromLTRB(small ? 7 : 10, 12, 48, 12),
                          child: grid
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: SizedBox.expand(child: thumb),
                                    ),
                                    const SizedBox(height: 8),
                                    label,
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: small ? 70 : 78,
                                      height: small ? 47 : 51,
                                      child: thumb,
                                    ),
                                    SizedBox(width: small ? 8 : 10),
                                    Expanded(child: label),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    Positioned(top: 6, right: 6, child: check),
                  ],
                ),
              ),
            );
          },
        );
      }

      return grid
          ? GridView.builder(
              key: const PageStorageKey('library-grid-scroll'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: (bounds.maxWidth / 220).floor().clamp(1, 6),
                mainAxisExtent:
                    300 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: tile,
            )
          : ListView.builder(
              key: const PageStorageKey('library-list-scroll'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: items.length,
              itemBuilder: tile,
            );
    },
  );
}

class _HoverTile extends StatefulWidget {
  final Widget Function(bool) builder;
  const _HoverTile({required this.builder});
  @override
  State<_HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<_HoverTile> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hover = true),
    onExit: (_) => setState(() => hover = false),
    child: widget.builder(hover),
  );
}
