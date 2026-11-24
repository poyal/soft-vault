import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

typedef _Set = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _Command = Int32 Function(Pointer<Void>, Pointer<Pointer<Utf8>>);
typedef _Trial =
    Int32 Function(
      Pointer<Void>,
      Pointer<NativeFunction<_Set>>,
      Pointer<NativeFunction<_Command>>,
      Int32,
      Int64,
    );

class SeekDispatchTrial {
  final Pointer<Void> handle;
  final DynamicLibrary mpv;
  final DynamicLibrary helper;
  late final setPointer = mpv.lookup<NativeFunction<_Set>>(
    'mpv_set_property_string',
  );
  late final commandPointer = mpv.lookup<NativeFunction<_Command>>(
    'mpv_command',
  );
  late final set = setPointer
      .asFunction<int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)>();
  late final command = commandPointer
      .asFunction<int Function(Pointer<Void>, Pointer<Pointer<Utf8>>)>();
  late final cpp = helper
      .lookupFunction<
        _Trial,
        int Function(
          Pointer<Void>,
          Pointer<NativeFunction<_Set>>,
          Pointer<NativeFunction<_Command>>,
          int,
          int,
        )
      >('trial_seek');
  late final openWindow = helper
      .lookupFunction<IntPtr Function(Int32, Int32), int Function(int, int)>(
        'trial_window_open',
      );
  late final windowFrame = helper
      .lookupFunction<Int32 Function(), int Function()>('trial_window_frame');
  late final closeWindow = helper
      .lookupFunction<Void Function(), void Function()>('trial_window_close');

  SeekDispatchTrial(int address, String helperPath)
    : handle = Pointer.fromAddress(address),
      helper = DynamicLibrary.open(helperPath),
      mpv = DynamicLibrary.open(
        p.join(
          p.dirname(Platform.resolvedExecutable),
          Platform.isWindows
              ? 'libmpv-2.dll'
              : '../Frameworks/Mpv.framework/Mpv',
        ),
      );

  void dispatch(bool useCpp, int index, int originMs) {
    var result = 0;
    if (useCpp) {
      result = cpp(handle, setPointer, commandPointer, index, originMs);
    } else if (index == 10 || index.isEven) {
      final ms = originMs + (index == 10 ? 10 : index + 1) * 5000;
      result = using((arena) {
        final seconds = (ms / 1000)
            .toStringAsFixed(3)
            .toNativeUtf8(allocator: arena);
        if (index == 0 || index == 10) {
          return set(
            handle,
            'time-pos'.toNativeUtf8(allocator: arena),
            seconds,
          );
        }
        final args = arena<Pointer<Utf8>>(4);
        args[0] = 'seek'.toNativeUtf8(allocator: arena);
        args[1] = seconds;
        args[2] = 'absolute+keyframes'.toNativeUtf8(allocator: arena);
        args[3] = nullptr;
        return command(handle, args);
      });
    }
    if (result < 0) throw StateError('libmpv seek failed ($result)');
  }
}
