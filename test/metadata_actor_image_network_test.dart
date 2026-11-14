import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/metadata_actor_image.dart';

class _NetworkHttpOverrides extends HttpOverrides {}

// Opt in with --dart-define=ACTOR_IMAGE_TEST_URL=<public HTTPS image>.
// Keep ordinary tests independent of external services and network access.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('ACTOR_IMAGE_TEST_URL');
  test(
    'public HTTPS image downloads over TLS and decodes for metadata import',
    () async {
      final bytes = await HttpOverrides.runWithHttpOverrides(
        () => downloadActorImage(url),
        _NetworkHttpOverrides(),
      );
      expect(bytes, isNotEmpty);
      final png = await validateActorImage(bytes);
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    },
    skip: url.isEmpty
        ? 'Set ACTOR_IMAGE_TEST_URL to run the live TLS check.'
        : false,
    timeout: const Timeout(Duration(seconds: 40)),
  );
}
