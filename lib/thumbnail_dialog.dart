import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'media_tools.dart';
import 'scenes_dialog.dart';

class ThumbnailDialog extends StatefulWidget {
  final Map<String, Object?> item;
  final MediaTools tools;
  final double position;
  const ThumbnailDialog({
    super.key,
    required this.item,
    required this.tools,
    this.position = 0,
  });
  @override
  State<ThumbnailDialog> createState() => _ThumbnailDialogState();
}

class _ThumbnailDialogState extends State<ThumbnailDialog> {
  final candidates = <({String path, double seconds})>[];
  String? selected, error;
  bool loading = false, saving = false;
  @override
  void initState() {
    super.initState();
    generate();
  }

  Future<void> generate() async {
    if (widget.item['type'] != 'video') return;
    setState(() => loading = true);
    try {
      final duration = (widget.item['duration'] as num).toDouble();
      final times = {
        widget.position,
        for (final ratio in [.1, .25, .5, .75, .9]) duration * ratio,
      };
      for (final seconds in times) {
        if (!mounted) break;
        final path = await widget.tools.frame(widget.item, seconds);
        if (mounted)
          setState(() => candidates.add((path: path, seconds: seconds)));
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (selected == null) return;
    setState(() => saving = true);
    try {
      await widget.tools.setThumbnail(widget.item['id'] as int, selected!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('대표 썸네일 선택'),
    content: SizedBox(
      width: 760,
      height: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('영상 장면이나 로컬 이미지를 선택하세요. 원본 영상은 변경되지 않습니다.'),
          const SizedBox(height: 16),
          if (loading || saving) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.orange)),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: candidates
                  .map(
                    (candidate) => InkWell(
                      onTap: () => setState(() => selected = candidate.path),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected == candidate.path
                                ? const Color(0xff87b8d8)
                                : const Color(0xff323d49),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(candidate.path), fit: BoxFit.cover),
                            Positioned(
                              bottom: 4,
                              left: 6,
                              child: Text(
                                sceneTime((candidate.seconds * 1000).round()),
                                style: const TextStyle(
                                  backgroundColor: Color(0xaa000000),
                                ),
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
          if (selected != null)
            Text(
              '선택됨: ${selected!.split(Platform.pathSeparator).last}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: saving
            ? null
            : () async {
                final image = await openFile(
                  acceptedTypeGroups: [
                    const XTypeGroup(
                      label: '이미지',
                      extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
                    ),
                  ],
                );
                if (image != null && mounted)
                  setState(() {
                    selected = image.path;
                    candidates.add((path: image.path, seconds: 0));
                  });
              },
        child: const Text('이미지 파일 선택'),
      ),
      OutlinedButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  await widget.tools.resetThumbnail(widget.item['id'] as int);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (mounted) setState(() => error = '$e');
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
        child: const Text('자동 썸네일로 복원'),
      ),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: selected == null || saving ? null : save,
        child: const Text('적용'),
      ),
    ],
  );
}
