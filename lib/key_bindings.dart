import 'package:flutter/services.dart';
import 'library.dart';

String chord(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool control = false,
  bool alt = false,
}) =>
    '${control ? 'Ctrl+' : ''}${shift ? 'Shift+' : ''}${alt ? 'Alt+' : ''}${key.keyId}';
String eventChord(KeyEvent event) => chord(
  event.logicalKey,
  shift: HardwareKeyboard.instance.isShiftPressed,
  control:
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed,
  alt: HardwareKeyboard.instance.isAltPressed,
);
String chordLabel(String value) {
  final parts = value.split('+');
  final id = int.tryParse(parts.last);
  if (id != null)
    parts[parts.length - 1] =
        {
          LogicalKeyboardKey.space.keyId: 'Space',
          LogicalKeyboardKey.arrowLeft.keyId: '←',
          LogicalKeyboardKey.arrowRight.keyId: '→',
          LogicalKeyboardKey.arrowUp.keyId: '↑',
          LogicalKeyboardKey.arrowDown.keyId: '↓',
          LogicalKeyboardKey.pageUp.keyId: 'PageUp',
          LogicalKeyboardKey.pageDown.keyId: 'PageDown',
          LogicalKeyboardKey.backspace.keyId: 'Backspace',
        }[id] ??
        LogicalKeyboardKey(id).keyLabel;
  return parts.join(' + ');
}

class KeyBindings {
  final Library library;
  late Map<String, List<String>> values = defaults();
  KeyBindings(this.library);
  static const labels = <String, String>{
    'pause': '재생 · 일시정지',
    'back': '5초 뒤로',
    'forward': '5초 앞으로',
    'preciseBack': '1초 뒤로',
    'preciseForward': '1초 앞으로',
    'volumeUp': '볼륨 5% 올리기',
    'volumeDown': '볼륨 5% 내리기',
    'mute': '음소거 켜기 · 끄기',
    'previous': '이전 파일',
    'next': '다음 파일',
    'fullscreen': '전체 화면',
    'slower': '배속 낮추기',
    'faster': '배속 높이기',
    'normalSpeed': '배속 1배',
    'undoSeek': '직전 탐색 복귀',
    'rate1': '평점 1',
    'rate2': '평점 2',
    'rate3': '평점 3',
    'rate4': '평점 4',
    'rate5': '평점 5',
    'clearRating': '평점 초기화',
    'tags': '태그 편집',
    'actors': '배우 편집',
    'detail': '상세 편집',
    'move': '폴더 이동',
    'search': '검색',
    'help': '단축키 안내',
  };
  static Map<String, List<String>> defaults() => {
    'pause': [chord(LogicalKeyboardKey.space)],
    'back': [
      chord(LogicalKeyboardKey.arrowLeft),
      chord(LogicalKeyboardKey.keyA),
    ],
    'forward': [
      chord(LogicalKeyboardKey.arrowRight),
      chord(LogicalKeyboardKey.keyD),
    ],
    'preciseBack': [
      chord(LogicalKeyboardKey.arrowLeft, shift: true),
      chord(LogicalKeyboardKey.keyA, shift: true),
    ],
    'preciseForward': [
      chord(LogicalKeyboardKey.arrowRight, shift: true),
      chord(LogicalKeyboardKey.keyD, shift: true),
    ],
    'volumeUp': [
      chord(LogicalKeyboardKey.arrowUp),
      chord(LogicalKeyboardKey.keyW),
    ],
    'volumeDown': [
      chord(LogicalKeyboardKey.arrowDown),
      chord(LogicalKeyboardKey.keyS),
    ],
    'mute': [chord(LogicalKeyboardKey.keyM)],
    'previous': [
      chord(LogicalKeyboardKey.pageUp),
      chord(LogicalKeyboardKey.keyQ),
    ],
    'next': [
      chord(LogicalKeyboardKey.pageDown),
      chord(LogicalKeyboardKey.keyE),
    ],
    'fullscreen': [chord(LogicalKeyboardKey.keyF)],
    'slower': [chord(LogicalKeyboardKey.bracketLeft)],
    'faster': [chord(LogicalKeyboardKey.bracketRight)],
    'normalSpeed': [chord(LogicalKeyboardKey.backspace)],
    'undoSeek': [chord(LogicalKeyboardKey.backspace, shift: true)],
    for (var n = 1; n <= 5; n++)
      'rate$n': [
        chord(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + n - 1)),
      ],
    'clearRating': [chord(LogicalKeyboardKey.digit0, shift: true)],
    'tags': [chord(LogicalKeyboardKey.keyT)],
    'actors': [chord(LogicalKeyboardKey.keyP)],
    'detail': [chord(LogicalKeyboardKey.keyI)],
    'move': [chord(LogicalKeyboardKey.keyM, control: true, shift: true)],
    'search': [chord(LogicalKeyboardKey.keyK, control: true)],
    'help': [chord(LogicalKeyboardKey.slash, shift: true)],
  };
  Future<void> load() async {
    final saved = await library.readSetting('shortcuts');
    if (saved is Map) {
      for (final key in labels.keys) {
        if (saved[key] is List)
          values[key] = (saved[key] as List).cast<String>();
      }
    }
  }

  Future<void> save() => library.setting('shortcuts', values);
  String? resolve(KeyEvent event) {
    var key = eventChord(event);
    // Numpad ratings share the number-row mapping.
    for (var n = 0; n <= 9; n++) {
      if (event.logicalKey.keyId == LogicalKeyboardKey.numpad0.keyId + n) {
        key = key.replaceFirst(
          '${event.logicalKey.keyId}',
          '${LogicalKeyboardKey.digit0.keyId + n}',
        );
      }
    }
    for (final entry in values.entries) {
      if (entry.value.contains(key)) return entry.key;
    }
    return null;
  }

  String? assign(String command, int slot, String value) {
    final key = int.tryParse(value.split('+').last);
    if (key == LogicalKeyboardKey.escape.keyId ||
        key == LogicalKeyboardKey.digit0.keyId ||
        key == LogicalKeyboardKey.numpad0.keyId) {
      return 'Esc와 0은 예약되어 있습니다.';
    }
    for (final entry in values.entries) {
      if (entry.key != command && entry.value.contains(value))
        return '${labels[entry.key]}에서 사용 중입니다.';
    }
    final keys = List<String>.from(values[command] ?? []);
    if (slot < keys.length) {
      keys[slot] = value;
    } else {
      keys.add(value);
    }
    if (keys.toSet().length != keys.length) return '기본키와 보조키가 같습니다.';
    values[command] = keys;
    return null;
  }
}
