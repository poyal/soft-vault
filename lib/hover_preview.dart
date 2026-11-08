import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Animated image preview contains no audio stream or extra playback engine.
class HoverPreview extends StatefulWidget {
  final Widget child;
  final Future<String> Function()? load;
  const HoverPreview({super.key, required this.child, this.load});
  @override
  State<HoverPreview> createState() => _HoverPreviewState();
}

class _HoverPreviewState extends State<HoverPreview> {
  Timer? delay;
  bool hovered = false;
  String? path;
  @override
  void dispose() {
    delay?.cancel();
    super.dispose();
  }

  void enter() {
    hovered = true;
    delay = Timer(const Duration(milliseconds: 650), () async {
      try {
        final result = await widget.load?.call();
        if (mounted && hovered) setState(() => path = result);
      } catch (_) {
        /* Keep the original thumbnail. */
      }
    });
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => enter(),
    onExit: (_) {
      hovered = false;
      delay?.cancel();
      setState(() => path = null);
    },
    child: path == null
        ? widget.child
        : Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(path!), fit: BoxFit.cover, gaplessPlayback: true),
              const Positioned(
                right: 4,
                bottom: 4,
                child: Icon(Icons.volume_off_outlined, size: 12),
              ),
            ],
          ),
  );
}
