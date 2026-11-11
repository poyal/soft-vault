import 'package:flutter/material.dart';
import 'design.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;
  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: DeckDesign.sidebar,
      border: Border.all(color: DeckDesign.line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: DeckDesign.muted,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: DeckDesign.line),
          children[i],
        ],
      ],
    ),
  );
}

class SettingsRow extends StatelessWidget {
  final String title;
  final String? description;
  final Widget control;
  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    required this.control,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: DeckDesign.muted,
                ),
              ),
            ],
          ],
        );
        if (bounds.maxWidth < 560)
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 12), control],
          );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: copy),
            const SizedBox(width: 24),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bounds.maxWidth * .48),
              child: control,
            ),
          ],
        );
      },
    ),
  );
}

class SettingsStatus extends StatelessWidget {
  final String message;
  const SettingsStatus(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      message,
      style: const TextStyle(
        fontSize: 14,
        height: 1.5,
        color: DeckDesign.muted,
      ),
    ),
  );
}

class SettingsTheme extends StatelessWidget {
  final Widget child;
  const SettingsTheme({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: 15,
          fontFamily: DeckDesign.font,
          fontFamilyFallback: ['Malgun Gothic', 'Apple SD Gothic Neo'],
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
    return Theme(
      data: base.copyWith(
        cardTheme: CardThemeData(
          color: DeckDesign.sidebar,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: DeckDesign.line),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: DeckDesign.text,
          iconColor: DeckDesign.muted,
          selectedColor: DeckDesign.accent,
          selectedTileColor: DeckDesign.surface,
          minVerticalPadding: 12,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            side: const BorderSide(color: DeckDesign.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: style.copyWith(
            side: const WidgetStatePropertyAll(
              BorderSide(color: DeckDesign.line),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(style: style),
        textButtonTheme: TextButtonThemeData(style: style),
        dialogTheme: base.dialogTheme.copyWith(
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: DeckDesign.text,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: DeckDesign.text,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: DeckDesign.line),
          ),
        ),
      ),
      child: child,
    );
  }
}
