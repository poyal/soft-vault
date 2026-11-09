import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'design.dart';
import 'app_updater.dart';
import 'scenes_dialog.dart';

/// Measurements, colors and SVGs mirror design/side-deck.css.
class SideDeck extends StatelessWidget {
  final Widget stage;
  final Widget? controls, content, navigation, toolbar, fileList;
  final List<Map<String, Object?>> items;
  final Map<String, Object?>? current;
  final List<String> folders;
  final String? folder;
  final String query;
  final bool expanded, busy, playing;
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
    this.settingsOnly = false,
    this.filterCount = 0,
    this.filters,
    this.open,
  });
  static const mutedColor = DeckDesign.muted, line = DeckDesign.line;
  Widget folderButton(String? path) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      backgroundColor: folder == path
          ? const Color(0xff2b4050)
          : Colors.transparent,
      foregroundColor: folder == path
          ? const Color(0xffb9d3e5)
          : const Color(0xff8299a9),
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
      style: const TextStyle(fontSize: 9, height: 1.1),
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
            style: const TextStyle(fontSize: 10, color: Color(0xff5b7b92)),
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
                              fontSize: 10,
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
          TextButton(
            onPressed: edit,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 27),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Row(
              children: [
                DesignIcon('sliders', size: 12),
                SizedBox(width: 5),
                Text('상세정보', style: TextStyle(fontSize: 10)),
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
          style: TextStyle(fontSize: 11, color: Color(0xff6e8190)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: DesignIcon('chevron', size: 12),
        ),
        const Text(
          '전체 파일',
          style: TextStyle(fontSize: 11, color: Color(0xffa4b6c4)),
        ),
        const Spacer(),
        DeckIconButton('search', tooltip: '검색 · Ctrl/Cmd+K', onPressed: search),
        const SizedBox(width: 8),
        const KeyCap('Ctrl K'),
      ],
    ),
  );
  Widget preview(double width, double height) {
    final small = width <= 1280, padding = width <= 1280 ? 30.0 : 38.0;
    final leftWidth = width - (small ? 340 : 370);
    final stageHeight = math.max(
      small ? 200.0 : 230.0,
      math.min(
        (leftWidth - padding * 2) * 9 / 16,
        height - (small ? 440 : 465),
      ),
    );
    return Column(
      children: [
        Padding(padding: const EdgeInsets.only(right: 10), child: header()),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                padding,
                small ? 28 : 31,
                padding + 10,
                small ? 20 : 22,
              ),
              child: current == null
                  ? SizedBox(
                      height: height - 150,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'design/assets/app-icon.png',
                              width: 110,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              '나만의 영상을 한곳에',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '폴더를 연결하고, 원하는 장면을 쉽게 다시 찾아보세요.',
                              style: TextStyle(
                                fontSize: 13,
                                color: DeckDesign.muted,
                              ),
                            ),
                            const SizedBox(height: 28),
                            FilledButton(
                              onPressed: busy ? null : connect,
                              child: const Text('폴더 연결'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 80,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 7),
                                    const Text(
                                      'FILE PREVIEW',
                                      style: TextStyle(
                                        fontSize: 8,
                                        letterSpacing: 1.8,
                                        color: Color(0xff66869d),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      current!['title'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: -.8,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      p.basename(current!['path'] as String),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xff597589),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DeckIconButton(
                                'info',
                                tooltip: '상세정보 보기',
                                onPressed: edit,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          key: const ValueKey('preview-stage'),
                          height: stageHeight,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    .85,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    .85,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    .85,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    1,
                                    0,
                                  ]),
                                  child: stage,
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.transparent,
                                        Color(0x80101c25),
                                      ],
                                      stops: [0, .55, 1],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 15,
                                  left: 17,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xcc13212b),
                                      border: Border.all(
                                        color: const Color(0x22b7c9d2),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      [
                                            current!['resolution'],
                                            current!['codec'],
                                          ]
                                          .where((v) => v != null && v != '')
                                          .join(' · '),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Color(0xffadc1ce),
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  heightFactor: 1,
                                  child: Transform.translate(
                                    offset: const Offset(0, -14),
                                    child: Tooltip(
                                      message: '재생 화면 열기',
                                      child: InkWell(
                                        onTap: open,
                                        borderRadius: BorderRadius.circular(30),
                                        child: Container(
                                          width: 55,
                                          height: 55,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0x6e1b354a),
                                            border: Border.all(
                                              color: const Color(0x55d6e7f0),
                                            ),
                                          ),
                                          child: const DesignIcon(
                                            'play',
                                            size: 23,
                                            color: const Color(0xffe5edf2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.only(bottom: 15),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xff2c3944)),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '내 평점',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xff718c9f),
                                ),
                              ),
                              const SizedBox(width: 15),
                              DeckStars(
                                rating: current!['rating'] as int?,
                                change: rate,
                              ),
                              const Spacer(),
                              Text(
                                current!['type'] == 'video'
                                    ? sceneTime(
                                        ((current!['duration'] as num) * 1000)
                                            .round(),
                                      ).substring(3)
                                    : '${((current!['size'] as num) / 1048576).toStringAsFixed(1)} MB',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff688a9f),
                                ),
                              ),
                            ],
                          ),
                        ),
                        terms('actors', '배우'),
                        terms('tags', '태그'),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            current!['description'] as String,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff738da0),
                              height: 1.9,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 24),
                          padding: const EdgeInsets.only(top: 18),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xff27333e)),
                            ),
                          ),
                          child: const Row(
                            children: [
                              KeyCap('Esc'),
                              SizedBox(width: 6),
                              Text(
                                '소리 0% · 최소화',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xff4e6d82),
                                ),
                              ),
                              Spacer(),
                              Text(
                                '목록 제목은 미리보기 · 썸네일은 열기',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xff4e6d82),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget player() => ColoredBox(
    color: const Color(0xff0e1419),
    child: Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: expanded
                ? EdgeInsets.zero
                : const EdgeInsets.only(bottom: 166),
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
                        : preview(bounds.maxWidth, bounds.maxHeight)),
              ),
              if (!expanded)
                Container(
                  key: const ValueKey('library-sidebar'),
                  width: bounds.maxWidth <= 1280 ? 340 : 370,
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
                              const Text(
                                'soft vault.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
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
                        padding: const EdgeInsets.fromLTRB(19, 20, 19, 12),
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
                        padding: const EdgeInsets.fromLTRB(22, 5, 22, 4),
                        child: Row(
                          children: [
                            Text(
                              playing ? '재생 목록' : '전체 파일',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xffc4d3df),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              '${items.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xff6f8ca1),
                              ),
                            ),
                            const Spacer(),
                            DeckIconButton(
                              'filter',
                              tooltip: '필터',
                              onPressed: filters,
                              size: 18,
                            ),
                            if (filterCount > 0)
                              Text(
                                '$filterCount',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: DeckDesign.accent,
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
                                fontSize: 9,
                                color: Color(0xff6a899e),
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
                                      fontSize: 10,
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
