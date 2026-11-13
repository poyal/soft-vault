import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'design_icons.dart';

abstract final class DeckDesign {
  static const background = Color(0xff12161c),
      sidebar = Color(0xff1b222b),
      surface = Color(0xff242e3a),
      line = Color(0xff46576a),
      text = Color(0xfff0f4f8),
      muted = Color(0xffbcc8d5),
      accent = Color(0xff92c9f5),
      gold = Color(0xffbdaf8c);
  static const font = 'Segoe UI';
}

class DesignIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const DesignIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.color = DeckDesign.muted,
  });
  @override
  Widget build(BuildContext context) {
    // A runtime colorFilter makes vector_graphics save an offscreen layer for
    // every icon. Encode the monochrome stroke directly instead, preserving
    // geometry and group opacity without an extra pass for opaque icons.
    final stroke = (color.toARGB32() & 0xffffff)
        .toRadixString(16)
        .padLeft(6, '0');
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#$stroke" opacity="${color.a}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${designIconPaths[name] ?? designIconPaths['info']}</svg>',
      width: size,
      height: size,
    );
  }
}

class DeckIconButton extends StatelessWidget {
  final String name, tooltip;
  final VoidCallback? onPressed;
  final double size, extent;
  final bool outlined;
  const DeckIconButton(
    this.name, {
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.size = 20,
    this.extent = 30,
    this.outlined = true,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: extent < 40 ? 40 : extent,
    height: extent < 40 ? 40 : extent,
    child: IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: DesignIcon(name, size: size),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        backgroundColor: outlined ? DeckDesign.surface : Colors.transparent,
        side: outlined
            ? const BorderSide(color: DeckDesign.line)
            : BorderSide.none,
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  );
}

class KeyCap extends StatelessWidget {
  final String text;
  const KeyCap(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    constraints: const BoxConstraints(minWidth: 20),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    decoration: BoxDecoration(
      color: const Color(0xff1b2a36),
      border: Border.all(color: const Color(0xff314353)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xffb3c1cd),
          fontWeight: FontWeight.w400,
        ),
      ),
    ),
  );
}

class DeckStars extends StatelessWidget {
  final int? rating;
  final ValueChanged<int?>? change;
  final double size, gap;
  final Size? hitSize;
  const DeckStars({
    super.key,
    this.rating,
    this.change,
    this.size = 19,
    this.gap = 6,
    this.hitSize,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Padding(
          padding: EdgeInsets.only(right: i == 5 ? 0 : gap),
          child: change == null
              ? star(i)
              : Tooltip(
                  message: '$i점',
                  child: SizedBox(
                    width: hitSize?.width,
                    height: hitSize?.height,
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () => change!(i),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: star(i),
                      ),
                    ),
                  ),
                ),
        ),
    ],
  );
  Widget star(int i) => SizedBox(
    width: size + 1,
    height: size + 3,
    child: Text(
      '★',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size,
        height: 1.1,
        color: (rating ?? 0) >= i ? DeckDesign.gold : const Color(0xff344654),
      ),
    ),
  );
}

Future<T?> showDeckDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierColor: const Color(0x99050806),
  builder: (context) => BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
    child: builder(context),
  ),
);
