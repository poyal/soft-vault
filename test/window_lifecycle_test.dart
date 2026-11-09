import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/window_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Windows closes its window before ending the native event loop',
    () async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('window_manager');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await closeAppWindow();
      expect(calls.map((call) => call.method), ['setPreventClose', 'close']);
      expect(calls.first.arguments, {'isPreventClose': false});
    },
    skip: !Platform.isWindows,
  );
}
