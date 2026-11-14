import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

class MetadataActorImage {
  final String name, imageUrl, previousImage;
  Uint8List? bytes;
  String? error;
  MetadataActorImage(this.name, this.imageUrl, this.previousImage);
}

/// Downloads only public HTTPS images; redirects receive the same validation.
Future<Uint8List> downloadActorImage(String url) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..findProxy = (_) => 'DIRECT';
  try {
    return await (() async {
      var uri = Uri.parse(url);
      for (var redirect = 0; redirect < 4; redirect++) {
        if (uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            (uri.hasPort && uri.port != 443)) {
          throw const FormatException('공개 HTTPS 이미지 주소가 필요합니다.');
        }
        final addresses = await InternetAddress.lookup(uri.host);
        if (addresses.isEmpty ||
            addresses.any((a) {
              final b = a.rawAddress;
              if (a.isLoopback || a.isLinkLocal || a.isMulticast) return true;
              if (a.type == InternetAddressType.IPv4) {
                return b[0] == 0 ||
                    b[0] == 10 ||
                    b[0] == 127 ||
                    b[0] >= 224 ||
                    (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
                    (b[0] == 192 && b[1] == 168) ||
                    (b[0] == 100 && b[1] >= 64 && b[1] <= 127);
              }
              return b[0] & 0xe0 != 0x20;
            }))
          throw const FormatException('공개 인터넷 이미지 주소만 사용할 수 있습니다.');
        // A custom factory must establish TLS itself. Lookup results retain the
        // original hostname for SNI and certificate validation while pinning IPs.
        client.connectionFactory = (uri, proxyHost, proxyPort) =>
            SecureSocket.startConnect(addresses.first, uri.port);
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        final response = await request.close();
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) throw const FormatException('이미지 이동 주소가 없습니다.');
          uri = uri.resolve(location);
          continue;
        }
        if (response.statusCode != 200)
          throw HttpException('이미지를 불러오지 못했습니다 (${response.statusCode}).');
        const limit = 10 * 1024 * 1024;
        if (response.contentLength > limit)
          throw const FormatException('이미지는 10MB 이하여야 합니다.');
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response) {
          bytes.add(chunk);
          if (bytes.length > limit)
            throw const FormatException('이미지는 10MB 이하여야 합니다.');
        }
        return bytes.takeBytes();
      }
      throw const FormatException('이미지 주소의 이동 횟수가 너무 많습니다.');
    })().timeout(const Duration(seconds: 25));
  } finally {
    client.close(force: true);
  }
}

Future<Uint8List> validateActorImage(Uint8List bytes) async {
  if (bytes.length > 10 * 1024 * 1024)
    throw const FormatException('이미지는 10MB 이하여야 합니다.');
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 32000000) {
      throw const FormatException('이미지 해상도가 너무 큽니다.');
    }
    final scale =
        1024 /
        (descriptor.width > descriptor.height
            ? descriptor.width
            : descriptor.height);
    codec = await descriptor.instantiateCodec(
      targetWidth: scale < 1
          ? (descriptor.width * scale).round().clamp(1, 1024)
          : null,
      targetHeight: scale < 1
          ? (descriptor.height * scale).round().clamp(1, 1024)
          : null,
    );
    image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw const FormatException('이미지를 읽을 수 없습니다.');
    return png.buffer.asUint8List();
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
