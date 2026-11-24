// dart tool/seek_recovery_media.dart <ffmpeg> <directory> [name]
// The centre strip encodes the source frame number, even across VFR gaps.
import 'dart:io';

Future<void> main(List<String> args) async {
  final out = await Directory(args[1]).create(recursive: true);
  for (final spec in [
    ('long-gop', 1920, 1080, 24, 240, 'libx264'),
    ('1080p60', 1920, 1080, 60, 120, 'libx264'),
    ('vfr', 1920, 1080, 30, 60, 'libx264'),
    ('4k60', 3840, 2160, 60, 120, 'libx265'),
  ]) {
    final (name, width, height, fps, gop, codec) = spec;
    if (args.length > 2 && args[2] != name) continue;
    final stripe = width ~/ 16;
    final filters = [
      'drawbox=x=0:y=ih*.4:w=iw:h=ih*.2:c=black:t=fill',
      for (var i = 0; i < 16; i++)
        if (i != 14)
          'drawbox=x=${i * stripe}:y=ih*.4:w=$stripe:h=ih*.2:c=white:t=fill'
              "${i == 0 || i == 15 ? '' : ":enable='bitand(n,${1 << (i - 1)})'"}",
      if (name == 'vfr') "select='if(lt(mod(t,6),3),not(mod(n,2)),1)'",
    ];
    final run = await Process.start(args[0], [
      '-v',
      'error',
      '-nostdin',
      '-n',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=${width}x$height:rate=$fps',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=48000',
      '-t',
      '72',
      '-vf',
      filters.join(','),
      '-fps_mode',
      'vfr',
      '-c:v',
      codec,
      '-preset',
      'ultrafast',
      '-threads',
      '4',
      if (name == '4k60') ...[
        '-x265-params',
        'pools=4:frame-threads=2:scenecut=0',
        '-pix_fmt',
        'yuv420p10le',
      ],
      if (name != '4k60') ...['-sc_threshold', '0'],
      '-g',
      '$gop',
      '-bf',
      '2',
      '-c:a',
      'aac',
      '${out.path}/$name.mkv',
    ], mode: ProcessStartMode.inheritStdio);
    if (await run.exitCode != 0) throw StateError('FFmpeg failed for $name');
  }
}
