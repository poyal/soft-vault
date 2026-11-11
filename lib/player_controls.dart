import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'design.dart';

String clockText(Duration value) =>
    '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

class PlaybackControls extends StatelessWidget {
  final Player player;
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
    builder: (context, bounds) => StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, snapshot) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                clockText(snapshot.data!),
                style: const TextStyle(fontSize: 14, color: Color(0xffa0b59e)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Slider(
                  value: snapshot.data!.inMilliseconds.toDouble().clamp(
                    0,
                    player.state.duration.inMilliseconds.toDouble().clamp(
                      1,
                      double.infinity,
                    ),
                  ),
                  max: player.state.duration.inMilliseconds.toDouble().clamp(
                    1,
                    double.infinity,
                  ),
                  onChanged: (value) =>
                      player.seek(Duration(milliseconds: value.round())),
                ),
              ),
              const SizedBox(width: 15),
              Text(
                clockText(player.state.duration),
                style: const TextStyle(fontSize: 14, color: Color(0xffa0b59e)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 4,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DeckIconButton(
                'prev',
                tooltip: '이전 파일',
                onPressed: () => command('previous'),
                extent: 38,
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
                extent: 38,
              ),
              const SizedBox(width: 6),
              DeckIconButton(
                muted || player.state.volume == 0 ? 'muted' : 'volume',
                tooltip: '음소거',
                onPressed: () => command('mute'),
                extent: 38,
              ),
              SizedBox(
                width: bounds.maxWidth <= 940 ? 48 : 70,
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
              const SizedBox(width: 6),
              StreamBuilder<double>(
                stream: player.stream.volume,
                initialData: player.state.volume,
                builder: (_, snapshot) => SizedBox(
                  width: 48,
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
              const SizedBox(width: 16),
              DeckStars(rating: rating, change: rate, size: 17, gap: 3),
              Container(
                height: 22,
                width: 1,
                color: const Color(0xff3a4a35),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              PopupMenuButton<double>(
                tooltip: '재생 속도',
                onSelected: player.setRate,
                itemBuilder: (_) => [
                  for (final speed in [.25, .5, .75, 1.0, 1.25, 1.5, 2.0, 3.0])
                    PopupMenuItem(value: speed, child: Text('${speed}×')),
                ],
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: DeckDesign.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${player.state.rate.toStringAsFixed(1)}×',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xff95b6cf),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DeckIconButton(
                'info',
                tooltip: '상세정보 보기',
                onPressed: detail,
                extent: 38,
              ),
              const SizedBox(width: 8),
              DeckIconButton(
                'expand',
                tooltip: '전체 화면',
                onPressed: () => command('fullscreen'),
                extent: 38,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 4,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              KeyCap('Esc'),
              SizedBox(width: 6),
              Text(
                '소리 0% · 최소화',
                style: TextStyle(fontSize: 14, color: DeckDesign.muted),
              ),
              SizedBox(width: 16),
              KeyCap('Q'),
              SizedBox(width: 4),
              KeyCap('E'),
              SizedBox(width: 6),
              Text(
                '파일 이동',
                style: TextStyle(fontSize: 14, color: DeckDesign.muted),
              ),
              SizedBox(width: 16),
              KeyCap('W'),
              SizedBox(width: 4),
              KeyCap('S'),
              SizedBox(width: 6),
              Text(
                '음량',
                style: TextStyle(fontSize: 14, color: DeckDesign.muted),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
