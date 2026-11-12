import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'design.dart';
import 'app_updater.dart';

/// Measurements, colors and SVGs mirror design/side-deck.css.
class SideDeck extends StatelessWidget {
  final Widget stage;
  final double? sidebarWidth;
  final ValueChanged<double>? resizeSidebar;
  final Widget? controls, content, navigation, toolbar, fileList;
  final List<Map<String, Object?>> items;
  final Map<String, Object?>? current;
  final List<String> folders;
  final String? folder;
  final String query;
  final bool expanded, busy, playing, scanning;
  final int filterCount;
  final bool settingsOnly;
  final VoidCallback connect, search, edit, rescan, clearSearch, settings;
  final VoidCallback? filters, open;
  final ValueChanged<String?> chooseFolder;
  final ValueChanged<Map<String, Object?>> select;
  final ValueChanged<int?> rate;
  final ValueChanged<String> searchTerm;
  final void Function(String, List<int>)? folderDrop;
  const SideDeck({
    super.key,
    required this.stage,
    this.sidebarWidth,
    this.resizeSidebar,
    this.controls,
    this.content,
    this.navigation,
    this.toolbar,
    required this.settings,
    this.fileList,
    required this.items,
    required this.current,
    required this.folders,
    required this.folder,
    required this.query,
    required this.expanded,
    required this.busy,
    required this.connect,
    required this.search,
    required this.edit,
    required this.rescan,
    required this.clearSearch,
    required this.chooseFolder,
    required this.select,
    required this.rate,
    required this.searchTerm,
    this.folderDrop,
    this.playing = false,
    this.scanning = false,
    this.settingsOnly = false,
    this.filterCount = 0,
    this.filters,
    this.open,
  });
  static const mutedColor = DeckDesign.muted, line = DeckDesign.line;
  Widget folderButton(String? path) => OutlinedButton(
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      backgroundColor: folder == path
          ? const Color(0xff2b4050)
          : Colors.transparent,
      foregroundColor: folder == path
          ? const Color(0xffb9d3e5)
          : DeckDesign.muted,
      side: BorderSide(
        color: folder == path
            ? const Color(0xff466073)
            : const Color(0xff374553),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    onPressed: () => chooseFolder(path),
    child: Text(
      path == null ? '전체 폴더' : p.basename(path),
      style: const TextStyle(fontSize: 14, height: 1.1),
    ),
  );
  Widget terms(String field, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 51,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: DeckDesign.muted),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: (current?[field] as String? ?? '')
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .map(
                  (term) => InkWell(
                    onTap: () => searchTerm(term),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff202d38),
                        border: Border.all(color: const Color(0xff314353)),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (field == 'actors') ...[
                            const DesignIcon(
                              'person',
                              size: 12,
                              color: Color(0xff8baac0),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            field == 'tags' ? '# $term' : term,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xff8baac0),
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
        if (field == 'actors')
          OutlinedButton(
            onPressed: edit,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Row(
              children: [
                DesignIcon('sliders', size: 12),
                SizedBox(width: 5),
                Text('상세정보', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
      ],
    ),
  );
  Widget header() => Container(
    height: 60,
    padding: const EdgeInsets.symmetric(horizontal: 30),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xff29333d))),
    ),
    child: Row(
      children: [
        const DesignIcon('panel', size: 18),
        const SizedBox(width: 20),
        const Text(
          '라이브러리',
          style: TextStyle(fontSize: 14, color: DeckDesign.muted),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: DesignIcon('chevron', size: 12),
        ),
        const Text(
          '전체 파일',
          style: TextStyle(fontSize: 14, color: Color(0xffa4b6c4)),
        ),
        const Spacer(),
        DeckIconButton('search', tooltip: '검색 · Ctrl/Cmd+K', onPressed: search),
        const SizedBox(width: 8),
        const KeyCap('Ctrl K'),
      ],
    ),
  );
  Widget player() => ColoredBox(
    color: const Color(0xff0e1419),
    child: Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: expanded
                ? EdgeInsets.zero
                : const EdgeInsets.only(bottom: 220),
            child: stage,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xf5162635)],
                stops: [0, .35],
              ),
            ),
            child: controls,
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => settingsOnly
      ? content!
      : LayoutBuilder(
          builder: (context, bounds) => Row(
            children: [
              Expanded(
                child:
                    content ??
                    (playing
                        ? player()
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'design/assets/app-icon.png',
                                  width: 80,
                                  height: 80,
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  '재생 대기 중',
                                  style: TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 12),
                                const Text('목록에서 영상을 더블클릭해 재생하세요'),
                                if (current != null)
                                  TextButton(
                                    onPressed: edit,
                                    child: const Text('선택 파일 상세정보'),
                                  ),
                              ],
                            ),
                          )),
              ),
              if (!expanded && resizeSidebar != null)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) => resizeSidebar!(
                      ((sidebarWidth ?? bounds.maxWidth * .4) -
                              details.delta.dx)
                          .clamp(400.0, math.min(640.0, bounds.maxWidth - 486)),
                    ),
                    child: const SizedBox(
                      width: 6,
                      height: double.infinity,
                      child: ColoredBox(color: DeckDesign.line),
                    ),
                  ),
                ),
              if (!expanded)
                Container(
                  key: const ValueKey('library-sidebar'),
                  width: (sidebarWidth ?? bounds.maxWidth * .4).clamp(
                    400.0,
                    math.max(400.0, math.min(640.0, bounds.maxWidth - 486)),
                  ),
                  decoration: const BoxDecoration(
                    color: DeckDesign.sidebar,
                    border: Border(left: BorderSide(color: Color(0xff313c47))),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 73,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Row(
                            children: [
                              Image.asset(
                                'design/assets/app-icon.png',
                                width: 28,
                                height: 28,
                              ),
                              const SizedBox(width: 9),
                              const Expanded(
                                child: Text(
                                  'soft vault.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (AppUpdater.instance != null)
                                ListenableBuilder(
                                  listenable: AppUpdater.instance!,
                                  builder: (context, _) =>
                                      AppUpdater.instance!.release == null
                                      ? const SizedBox.shrink()
                                      : const Tooltip(
                                          message: '새 업데이트가 있습니다',
                                          child: Icon(
                                            Icons.circle,
                                            size: 7,
                                            color: Colors.lightBlueAccent,
                                          ),
                                        ),
                                ),
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: IconButton(
                                  tooltip: scanning
                                      ? '전체 폴더 새로고침 중'
                                      : '전체 폴더 새로고침',
                                  onPressed: busy || scanning ? null : rescan,
                                  style: IconButton.styleFrom(
                                    backgroundColor: DeckDesign.surface,
                                    side: const BorderSide(
                                      color: DeckDesign.line,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  icon: scanning
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh, size: 20),
                                ),
                              ),
                              const SizedBox(width: 8),
                              DeckIconButton(
                                'search',
                                tooltip: '검색 · Ctrl/Cmd+K',
                                onPressed: search,
                                size: 19,
                                extent: 34,
                              ),
                              const SizedBox(width: 8),
                              DeckIconButton(
                                'settings',
                                tooltip: '설정',
                                onPressed: settings,
                                size: 19,
                                extent: 34,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (navigation != null) navigation!,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    folderButton(null),
                                    for (final root in folders)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 5),
                                        child: DragTarget<List<int>>(
                                          onAcceptWithDetails: (details) =>
                                              folderDrop?.call(
                                                root,
                                                details.data,
                                              ),
                                          builder: (_, _, _) =>
                                              folderButton(root),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            DeckIconButton(
                              'plus',
                              tooltip: '폴더 연결',
                              onPressed: busy ? null : connect,
                              size: 18,
                              extent: 25,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              playing ? '재생 목록' : '전체 파일',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xffc4d3df),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              '${items.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xffb3c1cd),
                              ),
                            ),
                            const Spacer(),
                            Tooltip(
                              message: '필터',
                              child: OutlinedButton.icon(
                                onPressed: filters,
                                icon: const DesignIcon('filter', size: 18),
                                label: Text(
                                  filterCount > 0 ? '필터 $filterCount' : '필터',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  backgroundColor: filterCount > 0
                                      ? DeckDesign.surface
                                      : null,
                                  foregroundColor: filterCount > 0
                                      ? DeckDesign.accent
                                      : DeckDesign.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (playing)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(22, 2, 22, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '파일을 열 때마다 볼륨 0%로 시작',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xffb3c1cd),
                              ),
                            ),
                          ),
                        )
                      else if (toolbar != null)
                        toolbar!,
                      if (query.isNotEmpty)
                        InkWell(
                          onTap: clearSearch,
                          child: Container(
                            color: const Color(0xff253b4e),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '검색: $query',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xffabc5d9),
                                    ),
                                  ),
                                ),
                                const DesignIcon('close', size: 13),
                              ],
                            ),
                          ),
                        ),
                      const Divider(height: 1, color: Color(0xff2e3944)),
                      Expanded(child: fileList ?? const SizedBox.shrink()),
                    ],
                  ),
                ),
            ],
          ),
        );
}
