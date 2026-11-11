import 'design.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'library.dart';

class SearchChoice {
  final String query;
  final Map<String, Object?>? item;
  final String? command;
  const SearchChoice(this.query, {this.item, this.command});
}

class LibrarySearchDialog extends StatefulWidget {
  final Library library;
  final String query;
  const LibrarySearchDialog({
    super.key,
    required this.library,
    required this.query,
  });
  @override
  State<LibrarySearchDialog> createState() => _LibrarySearchDialogState();
}

class _LibrarySearchDialogState extends State<LibrarySearchDialog> {
  late final input = TextEditingController(text: widget.query);
  List<Map<String, Object?>> matches = [];
  int generation = 0, selected = 0;
  bool choosing = false;
  @override
  void initState() {
    super.initState();
    load(widget.query);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load(String query) async {
    final current = ++generation;
    final items = await widget.library.items(query: query, limit: 3);
    if (mounted && current == generation)
      setState(() {
        matches = items.take(3).toList();
        selected = 0;
      });
  }

  void choose(int index) {
    if (choosing) return;
    choosing = true;
    final choice = index == 0
        ? SearchChoice(input.text)
        : index <= matches.length
        ? SearchChoice(input.text, item: matches[index - 1])
        : SearchChoice(
            input.text,
            command: index == matches.length + 1 ? 'folders' : 'settings',
          );
    Navigator.pop(context, choice);
  }

  Widget row(int index, Widget leading, String title, String subtitle) =>
      ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        selected: selected == index,
        selectedTileColor: const Color(0xff2c4659),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        leading: leading,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: DeckDesign.muted),
        ),
        trailing: const Icon(
          Icons.subdirectory_arrow_left,
          size: 14,
          color: DeckDesign.muted,
        ),
        onTap: () => choose(index),
      );
  @override
  Widget build(BuildContext context) => Dialog(
    alignment: const Alignment(0, -.27),
    child: SizedBox(
      width: 640,
      height: 524,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: Color(0xff87b8d8)),
                const SizedBox(width: 16),
                Expanded(
                  child: Focus(
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (input.value.composing.isValid &&
                          !input.value.composing.isCollapsed)
                        return KeyEventResult.ignored;
                      if (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                        choose(selected);
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                          event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        setState(
                          () => selected =
                              (selected +
                                      (event.logicalKey ==
                                              LogicalKeyboardKey.arrowDown
                                          ? 1
                                          : -1))
                                  .clamp(0, matches.length + 2),
                        );
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: input,
                      autofocus: true,
                      onChanged: load,
                      onSubmitted: (_) => choose(selected),
                      decoration: const InputDecoration(
                        hintText: '어떤 장면을 찾고 있나요?',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '검색 닫기',
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xff323d49)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '빠르게 찾아보기',
                    style: TextStyle(fontSize: 14, color: DeckDesign.muted),
                  ),
                ),
                row(
                  0,
                  const Icon(Icons.search, size: 20),
                  '라이브러리에서 찾기',
                  '파일명, 제목, 배우, 태그, 설명, 메모',
                ),
                for (var index = 0; index < matches.length; index++)
                  row(
                    index + 1,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 58,
                        height: 44,
                        child: Image.file(
                          File(matches[index]['thumbnail'] as String),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.movie_outlined),
                        ),
                      ),
                    ),
                    matches[index]['title'] as String,
                    p.basename(matches[index]['folder'] as String),
                  ),
                row(
                  matches.length + 1,
                  const Icon(Icons.folder_outlined, size: 20),
                  '폴더 연결 관리',
                  '내 폴더를 라이브러리에 연결',
                ),
                row(
                  matches.length + 2,
                  const Icon(Icons.keyboard_outlined, size: 20),
                  '단축키 설정',
                  '기본키와 보조키 변경',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xff323d49)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            child: Row(
              children: [
                const Text(
                  '↑ ↓ 선택 · Enter 열기',
                  style: TextStyle(fontSize: 14, color: DeckDesign.muted),
                ),
                const Spacer(),
                const Text(
                  'Esc 소리 0% · 최소화',
                  style: TextStyle(fontSize: 14, color: DeckDesign.muted),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => choose(0),
                  child: const Text('검색'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
