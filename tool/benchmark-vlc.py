"""Opt-in native-window libVLC benchmark. Never changes the user's VLC config.

VLC 3's displayed-picture counter does not reliably advance on paused seeks.
The standard probe records acknowledgements and steady playback statistics.
The optional numbered-frame mode samples a dedicated libVLC test window.
"""
import argparse
import ctypes as c
import json
import os
from pathlib import Path
import time


class Stats(c.Structure):
    _fields_ = [(name, kind) for name, kind in [
        ('read_bytes', c.c_int), ('input_bitrate', c.c_float),
        ('demux_read_bytes', c.c_int), ('demux_bitrate', c.c_float),
        ('demux_corrupted', c.c_int), ('demux_discontinuity', c.c_int),
        ('decoded_video', c.c_int), ('decoded_audio', c.c_int),
        ('displayed_pictures', c.c_int), ('lost_pictures', c.c_int),
        ('played_abuffers', c.c_int), ('lost_abuffers', c.c_int),
        ('sent_packets', c.c_int), ('sent_bytes', c.c_int),
        ('send_bitrate', c.c_float),
    ]]


def measure_bursts(player, seek, read_frame, count, save, records):
    """Ten 5-second clicks, then observe the numbered 60 fps video for 2 s."""
    for run in range(count):
        reset = 5500 + run % 9 * 97
        seek(player, reset)
        deadline = time.monotonic() + 8
        while not reset - 25 <= read_frame() * 1000 / 60 <= reset + 500:
            if time.monotonic() >= deadline:
                raise RuntimeError('VLC did not display the numbered fixture at the reset position')
            time.sleep(.016)
        time.sleep(.35)
        origin = read_frame()
        if origin < 0:
            raise RuntimeError('VLC test frame not visible')
        target = origin / 60 + 50
        for i in range(10):
            seek(player, round(1000 * (origin / 60 + (i + 1) * 5)))
            if i < 9:
                time.sleep(.080)
        release = time.monotonic()
        last_change = previous = last_readable = release
        last_frame = first_target = None
        longest = largest_gap = 0
        readable = unreadable = 0
        while previous - release < 2:
            start = time.monotonic()
            frame = read_frame()
            now = time.monotonic()
            if frame >= 0:
                readable += 1
                largest_gap = max(largest_gap, now - last_readable)
                last_readable = now
                if frame != last_frame:
                    longest = max(longest, now - last_change)
                    last_change, last_frame = now, frame
                if first_target is None and target - .021 <= frame / 60 <= target + now - release + .05:
                    first_target = (now - release) * 1000
            else:
                unreadable += 1
            previous = now
            time.sleep(max(0, .016 - (now - start)))
        if readable < 2:
            raise RuntimeError('Insufficient readable frames from the VLC test window')
        largest_gap = max(largest_gap, previous - last_readable)
        records.append({'round': run, 'gesture': 'taps', 'firstTargetMs': first_target,
                        'longestUnchangedMs': 1000 * max(longest, previous - last_change),
                        'readableSamples': readable, 'unreadableSamples': unreadable,
                        'largestSampleGapMs': 1000 * largest_gap})
        save()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--vlc', type=Path, required=True)
    parser.add_argument('--fixtures', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--seconds', type=int, default=300)
    parser.add_argument('--seeks', type=int, default=30)
    parser.add_argument('--filter', default='')
    parser.add_argument('--frame-window', type=Path,
                        help='Owned native window helper for numbered 1080p60 or 4k60 fixtures')
    args = parser.parse_args()
    dll_dir = os.add_dll_directory(str(args.vlc.resolve()))
    os.environ['VLC_PLUGIN_PATH'] = str(args.vlc.resolve() / 'plugins')
    vlc = c.CDLL(str(args.vlc.resolve() / 'libvlc.dll'))

    def api(name, result, *parameters):
        fn = getattr(vlc, 'libvlc_' + name)
        fn.restype, fn.argtypes = result, parameters
        return fn

    ptr, integer = c.c_void_p, c.c_int
    new = api('new', ptr, integer, c.POINTER(c.c_char_p))
    version = api('get_version', c.c_char_p)
    media_new = api('media_new_path', ptr, ptr, c.c_char_p)
    player_new = api('media_player_new_from_media', ptr, ptr)
    play = api('media_player_play', integer, ptr)
    pause = api('media_player_set_pause', None, ptr, integer)
    volume = api('audio_set_volume', integer, ptr, integer)
    seek = api('media_player_set_time', None, ptr, c.c_longlong)
    position = api('media_player_get_time', c.c_longlong, ptr)
    duration = api('media_player_get_length', c.c_longlong, ptr)
    stats = api('media_get_stats', integer, ptr, c.POINTER(Stats))
    stop = api('media_player_stop', None, ptr)
    player_release = api('media_player_release', None, ptr)
    media_release = api('media_release', None, ptr)
    release = api('release', None, ptr)
    surface = None
    if args.frame_window:
        surface = c.CDLL(str(args.frame_window.resolve()))
        surface.trial_window_open.argtypes = [integer, integer]
        surface.trial_window_open.restype = ptr
        surface.trial_window_frame.restype = integer
        surface.trial_window_close.restype = None
        set_window = api('media_player_set_hwnd', None, ptr, ptr)
    options = [b'--ignore-config', b'--no-media-library', b'--no-video-title-show',
               b'--avcodec-hw=any', b'--width=1280', b'--height=800', b'--quiet']
    instance = new(len(options), (c.c_char_p * len(options))(*options))
    if not instance:
        raise RuntimeError('Unable to create libVLC instance')
    report = {'version': version().decode(), 'options': [o.decode() for o in options],
              'measurement': 'paused set_time acknowledgement only; first-target-frame latency unavailable; native steady playback statistics, no Qt GUI dispatch', 'files': []}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if surface:
        report['measurement'] = 'numbered frames in owned libVLC window, 10 set_time calls 80ms apart'

    def save():
        args.output.write_text(json.dumps(report, indent=2), encoding='utf-8')

    try:
        for path in sorted(args.fixtures.iterdir()):
            if path.suffix not in ('.mp4', '.mkv') or args.filter not in path.name:
                continue
            record = {'file': path.name, 'seeks': [], 'playbackSamples': []}
            report['files'].append(record)
            media = media_new(instance, str(path.resolve()).encode('utf-8'))
            player = player_new(media)

            def sample():
                values = Stats()
                if not stats(media, c.byref(values)):
                    raise RuntimeError('VLC statistics unavailable')
                return {name: getattr(values, name) for name, _ in values._fields_}

            try:
                if surface:
                    if path.stem not in ('1080p60', '4k60'):
                        raise ValueError('Use a numbered 60 fps fixture in --frame-window mode')
                    window = surface.trial_window_open(752, 423)
                    if not window:
                        raise RuntimeError('Cannot create VLC test window')
                    set_window(player, window)
                volume(player, 0)
                if play(player) != 0:
                    raise RuntimeError('VLC playback failed')
                deadline = time.monotonic() + 15
                while (duration(player) <= 0 or position(player) <= 0) and time.monotonic() < deadline:
                    time.sleep(.02)
                if duration(player) <= 0:
                    raise RuntimeError('VLC did not open media')
                volume(player, 0)
                if surface:
                    record['bursts'] = []
                    measure_bursts(player, seek, surface.trial_window_frame, args.seeks,
                                   save, record['bursts'])
                    record['completed'] = True
                    continue
                pause(player, 1)
                time.sleep(.2)
                length = duration(player)
                tolerance = 72 if '-vfr' in path.name else 48
                for i in range(args.seeks):
                    target = round(length * (.1 + ((i * 37) % 79) / 100))
                    started = time.monotonic()
                    seek(player, target)
                    while True:
                        if abs(position(player) - target) <= tolerance:
                            break
                        if time.monotonic() - started > 15:
                            raise RuntimeError(f'VLC seek acknowledgement timeout at {target}; time={position(player)}')
                        time.sleep(.008)
                    record['seeks'].append({'targetSeconds': target / 1000,
                        'nativeFrameReadyMs': None,
                        'nativeSeekAcknowledgementMs': (time.monotonic() - started) * 1000,
                        'playbackTime': position(player) / 1000})
                    time.sleep(.03)
                seek(player, 2000)
                pause(player, 0)
                time.sleep(1)
                started = time.monotonic()
                while time.monotonic() - started < args.seconds:
                    current = sample()
                    current['elapsedMs'] = (time.monotonic() - started) * 1000
                    record['playbackSamples'].append(current)
                    time.sleep(1)
                record['completed'] = True
            except Exception as error:
                record['error'] = str(error)
                raise
            finally:
                stop(player)
                player_release(player)
                media_release(media)
                if surface:
                    surface.trial_window_close()
                save()
    finally:
        release(instance)
        dll_dir.close()
        save()


if __name__ == '__main__':
    main()
