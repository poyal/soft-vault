import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef _OpenNative =
    Int32 Function(
      Pointer<Pointer<Void>>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Uint32,
    );
typedef _Open =
    int Function(Pointer<Pointer<Void>>, Pointer<Utf16>, Pointer<Utf16>, int);
typedef _DeriveNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint8>,
      Uint32,
      Uint64,
      Pointer<Uint8>,
      Uint32,
      Uint32,
    );
typedef _Derive =
    int Function(
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      int,
      Pointer<Uint8>,
      int,
      int,
    );
typedef _CloseNative = Int32 Function(Pointer<Void>, Uint32);
typedef _Close = int Function(Pointer<Void>, int);

/// Windows CNG's PBKDF2-HMAC-SHA256, called only inside the password worker
/// isolate. Uses the same persisted format as the portable cryptography backend.
List<int> deriveWindowsPassword(
  String password,
  List<int> salt,
  int iterations,
) {
  final bcrypt = DynamicLibrary.open('bcrypt.dll');
  final open = bcrypt.lookupFunction<_OpenNative, _Open>(
    'BCryptOpenAlgorithmProvider',
  );
  final derive = bcrypt.lookupFunction<_DeriveNative, _Derive>(
    'BCryptDeriveKeyPBKDF2',
  );
  final close = bcrypt.lookupFunction<_CloseNative, _Close>(
    'BCryptCloseAlgorithmProvider',
  );
  final handle = calloc<Pointer<Void>>();
  final name = 'SHA256'.toNativeUtf16();
  final bytes = utf8.encode(password);
  final input = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
  final nonce = calloc<Uint8>(salt.length);
  final output = calloc<Uint8>(32);
  try {
    input.asTypedList(bytes.length).setAll(0, bytes);
    nonce.asTypedList(salt.length).setAll(0, salt);
    if (open(handle, name, nullptr, 0x00000008) != 0) {
      throw StateError('Unable to initialize password derivation');
    }
    if (derive(
          handle.value,
          input,
          bytes.length,
          nonce,
          salt.length,
          iterations,
          output,
          32,
          0,
        ) !=
        0) {
      throw StateError('Password derivation failed');
    }
    return List<int>.from(output.asTypedList(32));
  } finally {
    input.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
    output.asTypedList(32).fillRange(0, 32, 0);
    bytes.fillRange(0, bytes.length, 0);
    if (handle.value != nullptr) close(handle.value, 0);
    calloc.free(input);
    calloc.free(nonce);
    calloc.free(output);
    calloc.free(handle);
    malloc.free(name);
  }
}
