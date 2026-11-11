import 'package:flutter/material.dart';
import 'actor_images.dart';
import 'library.dart';
import 'metadata_exchange_dialog.dart';
import 'settings_components.dart';

class MetadataWorkspace extends StatefulWidget {
  final Library library;
  final ValueChanged<String> action;
  final VoidCallback? onApplied;
  final bool hasMedia;
  const MetadataWorkspace({
    super.key,
    required this.library,
    required this.action,
    required this.hasMedia,
    this.onApplied,
  });
  @override
  State<MetadataWorkspace> createState() => _MetadataWorkspaceState();
}

class _MetadataWorkspaceState extends State<MetadataWorkspace> {
  int section = 0, revision = 0;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 3; i++)
              ChoiceChip(
                label: Text(['영상정보 교환', '배우 이미지', 'NFO 관리'][i]),
                selected: section == i,
                onSelected: (_) => setState(() => section = i),
              ),
          ],
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: section,
          children: [
            MetadataExchangeDialog(
              library: widget.library,
              embedded: true,
              onApplied: () {
                if (mounted) setState(() => revision++);
                widget.onApplied?.call();
              },
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SettingsSection(
                title: '배우 대표 이미지',
                description: '배우를 검색하고 대표 이미지를 등록하거나 교체하세요.',
                children: [
                  ActorImages(
                    key: ValueKey(revision),
                    library: widget.library,
                    embeddedEditor: true,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SettingsSection(
                title: 'NFO 파일과 주고받기',
                description: widget.hasMedia
                    ? '선택한 영상의 제목·배우·태그·평점을 NFO 파일과 주고받습니다.'
                    : '라이브러리에서 영상을 선택하면 사용할 수 있습니다.',
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.hasMedia
                              ? () => widget.action('nfoImport')
                              : null,
                          icon: const Icon(Icons.file_open_outlined),
                          label: const Text('NFO 가져오기'),
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.hasMedia
                              ? () => widget.action('nfoExport')
                              : null,
                          icon: const Icon(Icons.save_alt),
                          label: const Text('NFO 내보내기'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
