import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'design.dart';
import 'library.dart';

class ActorImagePicker extends StatelessWidget {
  final TextEditingController controller;
  const ActorImagePicker({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              width: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: value.text.isEmpty
                    ? const ColoredBox(
                        color: DeckDesign.surface,
                        child: Icon(Icons.person_outline, size: 64),
                      )
                    : Image.file(
                        File(value.text),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text(
                            '이미지를 다시 선택해 주세요',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('대표 이미지 선택'),
                  onPressed: () async {
                    final picked = await openFile(
                      acceptedTypeGroups: [
                        const XTypeGroup(
                          label: '이미지',
                          extensions: ['png', 'jpg', 'jpeg', 'webp'],
                        ),
                      ],
                    );
                    if (picked == null) return;
                    try {
                      final codec = await ui.instantiateImageCodec(
                        await picked.readAsBytes(),
                      );
                      final frame = await codec.getNextFrame();
                      frame.image.dispose();
                      codec.dispose();
                      if (context.mounted) controller.text = picked.path;
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('이미지를 읽을 수 없습니다. 다른 파일을 선택해 주세요.'),
                          ),
                        );
                    }
                  },
                ),
                OutlinedButton(
                  onPressed: value.text.isEmpty
                      ? null
                      : () => controller.clear(),
                  child: const Text('이미지 제거'),
                ),
              ],
            ),
          ],
        ),
      );
}

class ActorImages extends StatefulWidget {
  final Library library;
  final bool embeddedEditor;
  const ActorImages({
    super.key,
    required this.library,
    this.embeddedEditor = false,
  });
  @override
  State<ActorImages> createState() => _ActorImagesState();
}

class _ActorImagesState extends State<ActorImages> {
  List<Map<String, Object?>> rows = [];
  String query = '', message = '';
  Map<String, Object?>? editing;
  bool saving = false;
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.library.entities('actors');
      if (mounted) setState(() => rows = data);
    } catch (_) {
      if (mounted) setState(() => message = '배우 목록을 불러오지 못했습니다.');
    }
  }

  Future<void> edit(Map<String, Object?> row) async {
    controller.text = row['image'] as String? ?? '';
    if (widget.embeddedEditor) {
      setState(() {
        editing = row;
        message = '';
      });
      return;
    }
    final save = await showDeckDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(row['name'].toString() + ' · 대표 이미지'),
        content: SingleChildScrollView(
          child: ActorImagePicker(controller: controller),
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
    if (save != true) return;
    await saveImage(row);
  }

  Future<void> saveImage(Map<String, Object?> row) async {
    if (saving) return;
    final path = controller.text;
    setState(() => saving = true);
    try {
      if (path.isNotEmpty) {
        final codec = await ui.instantiateImageCodec(
          await File(path).readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        frame.image.dispose();
        codec.dispose();
      }
      await widget.library.db.update(
        'actors',
        {'image': path},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      if (mounted)
        setState(() {
          message = '이미지를 저장했습니다.';
          editing = null;
        });
      await load();
    } catch (_) {
      if (mounted) setState(() => message = '이미지를 저장하지 못했습니다. 파일을 다시 확인해 주세요.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final editor = Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DeckDesign.surface,
          border: Border.all(color: DeckDesign.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: editing == null
            ? const Column(
                children: [
                  Icon(Icons.portrait_outlined, size: 48),
                  SizedBox(height: 16),
                  Text('배우를 선택해 이미지를 편집하세요'),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    editing!['name'].toString() + ' · 대표 이미지',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AbsorbPointer(
                    absorbing: saving,
                    child: ActorImagePicker(controller: controller),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: saving
                            ? null
                            : () => setState(() => editing = null),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: saving ? null : () => saveImage(editing!),
                        child: Text(saving ? '저장 중…' : '저장'),
                      ),
                    ],
                  ),
                ],
              ),
      );
      if (!widget.embeddedEditor) return actorList();
      if (bounds.maxWidth < 700)
        return Column(
          children: [actorList(), const SizedBox(height: 20), editor],
        );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: actorList()),
          const SizedBox(width: 24),
          Expanded(child: editor),
        ],
      );
    },
  );

  Widget actorList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        decoration: const InputDecoration(
          labelText: '배우 검색',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
      ),
      if (message.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(message),
        ),
      if (rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('등록된 배우가 없습니다. 배우 관리에서 먼저 추가해 주세요.'),
        ),
      if (rows.isNotEmpty)
        SizedBox(
          height: 280,
          child: Builder(
            builder: (context) {
              final shown = rows
                  .where(
                    (r) => (r['name'].toString() + ' ' + r['alias'].toString())
                        .toLowerCase()
                        .contains(query),
                  )
                  .toList();
              if (shown.isEmpty)
                return const Center(child: Text('검색 결과가 없습니다.'));
              return ListView.builder(
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final row = shown[index];
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      selected: editing?['id'] == row['id'],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: DeckDesign.line),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: Image.file(
                          File(row['image'] as String? ?? ''),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.person_outline),
                        ),
                      ),
                      title: Text(row['name'] as String),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: saving ? null : () => edit(row),
                    ),
                  );
                },
              );
            },
          ),
        ),
    ],
  );
}
