import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'design.dart';
import 'seek_controller.dart';

String clockText(Duration value) =>
    '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

class PlaybackControls extends StatelessWidget {
  final Player player;
  final SeekController seeks;
  final bool muted;
  final ValueChanged<String> command;
  final ValueChanged<double> volume;
  final VoidCallback subtitle, decoder;
  final Widget? more;
  final VoidCallback? detail;
  final int? rating;
  final ValueChanged<int?>? rate;
  const PlaybackControls({
    super.key,
    required this.player,
    required this.seeks,
    required this.muted,
    required this.command,
    required this.volume,
    required this.subtitle,
    required this.decoder,
    this.more,
    this.detail,
    this.rating,
    this.rate,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, snapshot) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlaybackSeekBar(
            seeks: seeks,
            positions: player.stream.position,
            durations: player.stream.duration,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  DeckIconButton(
                    'prev',
                    tooltip: '이전 파일',
                    onPressed: () => command('previous'),
                    extent: 40,
                    outlined: false,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Container(
                      width: 41,
                      height: 41,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xffb5d7ec),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => command('pause'),
                        tooltip: '재생 / 일시정지',
                        style: IconButton.styleFrom(
                          shape: const CircleBorder(),
                          side: BorderSide.none,
                        ),
                        icon: DesignIcon(
                          player.state.playing ? 'pause' : 'play',
                          color: const Color(0xff243e51),
                        ),
                      ),
                    ),
                  ),
                  DeckIconButton(
                    'next',
                    tooltip: '다음 파일',
                    onPressed: () => command('next'),
                    extent: 40,
                    outlined: false,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  StreamBuilder<double>(
                    stream: player.stream.volume,
                    initialData: player.state.volume,
                    builder: (_, level) => DeckIconButton(
                      muted || level.data == 0 ? 'muted' : 'volume',
                      tooltip: '음소거',
                      onPressed: () => command('mute'),
                      extent: 40,
                      outlined: false,
                    ),
                  ),
                  SizedBox(
                    width: bounds.maxWidth < 600 ? 64 : 88,
                    child: StreamBuilder<double>(
                      stream: player.stream.volume,
                      initialData: player.state.volume,
                      builder: (_, snapshot) => Slider(
                        value: snapshot.data!.clamp(0, 100),
                        max: 100,
                        onChanged: volume,
                      ),
                    ),
                  ),
                  StreamBuilder<double>(
                    stream: player.stream.volume,
                    initialData: player.state.volume,
                    builder: (_, snapshot) => SizedBox(
                      width: 38,
                      child: Text(
                        '${snapshot.data!.round()}%',
                        key: const ValueKey('volume-label'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xffa9c8de),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              DeckStars(
                rating: rating,
                change: rate,
                size: 17,
                gap: 2,
                hitSize: const Size(24, 36),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  PopupMenuButton<double>(
                    tooltip: '재생 속도',
                    onSelected: player.setRate,
                    itemBuilder: (_) => [
                      for (final speed in [
                        .25,
                        .5,
                        .75,
                        1.0,
                        1.25,
                        1.5,
                        2.0,
                        3.0,
                      ])
                        PopupMenuItem(value: speed, child: Text('${speed}×')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 40,
                      ),
                      width: 60,
                      alignment: Alignment.center,
                      child: StreamBuilder<double>(
                        stream: player.stream.rate,
                        initialData: player.state.rate,
                        builder: (_, rate) => Text(
                          '${rate.data!.toStringAsFixed(1)}×',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xff95b6cf),
                          ),
                        ),
                      ),
                    ),
                  ),
                  DeckIconButton(
                    'info',
                    tooltip: '상세정보 보기',
                    onPressed: detail,
                    extent: 40,
                    outlined: false,
                  ),
                  DeckIconButton(
                    'expand',
                    tooltip: '전체 화면',
                    onPressed: () => command('fullscreen'),
                    extent: 40,
                    outlined: false,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Only the timeline rebuilds for position events; the decoder never owns the
/// thumb during a drag or while the requested final frame is still pending.
class PlaybackSeekBar extends StatelessWidget {
  final SeekController seeks;
  final Stream<Duration> positions, durations;
  const PlaybackSeekBar({
    super.key,
    required this.seeks,
    required this.positions,
    required this.durations,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: durations,
    initialData: seeks.port.duration,
    builder: (_, duration) => StreamBuilder<Duration>(
      stream: positions,
      initialData: seeks.port.position,
      builder: (_, position) => ListenableBuilder(
        listenable: seeks,
        builder: (_, _) {
          final total = duration.data ?? Duration.zero;
          final shown = seeks.busy ? seeks.displayPosition : position.data!;
          final max = total.inMilliseconds
              .toDouble()
              .clamp(1, double.infinity)
              .toDouble();
          const style = TextStyle(fontSize: 14, color: Color(0xffa0b59e));
          final enabled = total > Duration.zero && seeks.enabled;
          return Row(
            children: [
              Text(
                clockText(shown),
                key: const ValueKey('seek-position'),
                style: style,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Slider(
                  key: const ValueKey('playback-seek-slider'),
                  value: shown.inMilliseconds.toDouble().clamp(0, max),
                  max: max,
                  onChangeStart: enabled ? (_) => seeks.beginDrag() : null,
                  onChanged: enabled
                      ? (value) =>
                            seeks.preview(Duration(milliseconds: value.round()))
                      : null,
                  onChangeEnd: enabled ? (_) => seeks.finish() : null,
                ),
              ),
              const SizedBox(width: 15),
              Text(clockText(total), style: style),
            ],
          );
        },
      ),
    ),
  );
}
