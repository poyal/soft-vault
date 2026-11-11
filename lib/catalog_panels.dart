import 'dart:ui' as ui;
import 'actor_images.dart';
import 'design.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'library.dart';

class CatalogPanel extends StatefulWidget {
  final Library library;
  final String kind;
  final ValueChanged<String> open;
  final VoidCallback openAll;
  final VoidCallback changed;
  const CatalogPanel({
    super.key,
    required this.library,
    required this.kind,
    required this.open,
    required this.openAll,
    required this.changed,
  });
  @override
  State<CatalogPanel> createState() => _CatalogPanelState();
}

class _CatalogPanelState extends State<CatalogPanel> {
  List<Map<String, Object?>> rows = [];
  String? error;
  int total = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await widget.library.entities(widget.kind);
    final count =
        (await widget.library.db.rawQuery(
              "SELECT count(*) AS n FROM media WHERE type='video'",
            )).single['n']
            as int;
    if (mounted)
      setState(() {
        rows = data;
        total = count;
      });
  }

  Future<void> edit([Map<String, Object?>? row]) async {
    final actor = widget.kind == 'actors';
    final fields = {
      for (final key
          in actor ? ['name', 'alias', 'description', 'image'] : ['name'])
        key: TextEditingController(text: row?[key] as String? ?? ''),
    };
    final labels = {
      'name': actor ? '배우 이름' : '태그 이름',
      'alias': '별칭',
      'description': '설명',
      'image': '대표 이미지 경로',
    };
    final result = await showDeckDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actor ? '배우 정보' : '태그 관리'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: field.value,
                      maxLines: field.key == 'description' ? 3 : 1,
                      decoration: InputDecoration(labelText: labels[field.key]),
                    ),
                  ),
                if (actor) ActorImagePicker(controller: fields['image']!),
                if (!actor)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('이미 있는 이름으로 바꾸면 해당 태그로 합쳐집니다.'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      if (actor) {
        final path = fields['image']!.text.trim();
        if (path.isNotEmpty && path != row?['image']) {
          final codec = await ui.instantiateImageCodec(
            await File(path).readAsBytes(),
          );
          final frame = await codec.getNextFrame();
          frame.image.dispose();
          codec.dispose();
        }
        await widget.library.saveActor(
          id: row?['id'] as int?,
          name: fields['name']!.text,
          alias: fields['alias']!.text,
          image: fields['image']!.text,
          description: fields['description']!.text,
        );
      } else {
        await widget.library.renameTag(
          row?['name'] as String? ?? '',
          fields['name']!.text,
        );
      }
      widget.changed();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(36, 34, 36, 36),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.kind == 'actors' ? '배우' : '태그',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            Text(
              '${rows.length}',
              style: const TextStyle(fontSize: 14, color: DeckDesign.muted),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: edit,
              icon: const Icon(Icons.add),
              label: Text(widget.kind == 'actors' ? '배우 추가' : '태그 추가'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.kind == 'actors'
              ? '이름 하나로, 연결된 모든 장면을 만나보세요.'
              : '하나의 파일에 여러 가지 이야기를 붙여보세요.',
          style: const TextStyle(color: DeckDesign.muted, fontSize: 14),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.orange)),
        const SizedBox(height: 20),
        Material(
          color: const Color(0xff263c4d),
          borderRadius: BorderRadius.circular(9),
          child: ListTile(
            key: ValueKey('${widget.kind}-all'),
            leading: const DesignIcon('film', size: 22),
            title: const Text('전체'),
            subtitle: Text('전체 영상 $total개'),
            trailing: const DesignIcon('chevron', size: 16),
            onTap: widget.openAll,
          ),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('아직 등록된 항목이 없습니다.'))
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    mainAxisExtent:
                        (widget.kind == 'actors' ? 240 : 100) *
                        MediaQuery.textScalerOf(context).scale(1),
                    crossAxisSpacing: widget.kind == 'actors' ? 22 : 18,
                    mainAxisSpacing: 18,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final image = row['image'] as String? ?? '';
                    if (widget.kind == 'tags')
                      return Material(
                        color: const Color(0xff1c2c39),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                          side: const BorderSide(color: Color(0xff334a5e)),
                        ),
                        child: InkWell(
                          onTap: () => widget.open(row['name'] as String),
                          onSecondaryTap: () => edit(row),
                          borderRadius: BorderRadius.circular(9),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                const DesignIcon(
                                  'tag',
                                  size: 22,
                                  color: Color(0xff8d9f76),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        row['name'] as String,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${row['count']}개 파일',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: DeckDesign.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DeckIconButton(
                                  'chevron',
                                  tooltip: '정보 편집',
                                  onPressed: () => edit(row),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    return Card(
                      margin: EdgeInsets.zero,
                      color: const Color(0xff1c2c39),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xff334a5e)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => widget.open(row['name'] as String),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 12, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: IconButton(
                                  onPressed: () => edit(row),
                                  tooltip: '정보 편집',
                                  icon: const DesignIcon('more', size: 18),
                                ),
                              ),
                              if (widget.kind == 'actors')
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: CircleAvatar(
                                    radius: 35,
                                    foregroundColor: const Color(0xffcbdce4),
                                    backgroundColor: const Color(0xff34403b),
                                    child: image.isNotEmpty
                                        ? ClipOval(
                                            child: Image.file(
                                              File(image),
                                              width: 70,
                                              height: 70,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.person_outline,
                                                    size: 56,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            (row['name'] as String).characters
                                                .skip(
                                                  (row['name'] as String)
                                                              .characters
                                                              .length >
                                                          2
                                                      ? 1
                                                      : 0,
                                                )
                                                .take(2)
                                                .toString(),
                                            style: const TextStyle(
                                              fontSize: 24,
                                            ),
                                          ),
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row['name'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${row['alias'] == null || row['alias'] == '' ? '' : '${row['alias']} · '}${row['count']}개 파일',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: DeckDesign.muted,
                                ),
                              ),
                            ],
                          ),
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
