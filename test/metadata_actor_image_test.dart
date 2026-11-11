import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/metadata_exchange.dart';
import 'package:soft_vault/metadata_actor_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Library library;
  late MetadataExchange service;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('actor-image-exchange-');
    library = await Library.open('${root.path}/db.sqlite');
    await library.db.insert('media', {
      'id': 1,
      'path': '${root.path}/video.mp4',
      'folder': root.path,
      'title': '영상',
      'type': 'video',
      'added': 1,
    });
    service = MetadataExchange(
      library,
      imageDownloader: (_) => File('design/assets/app-icon.png').readAsBytes(),
    );
  });
  tearDown(() async {
    await library.close();
    await root.delete(recursive: true);
  });
  Future<MetadataProposal> proposal() async {
    final request = await service.create();
    final response = jsonDecode(service.encode(request));
    response['videos'][0]['actors'] = ['배우 A'];
    response['videos'][0]['title'] = '수정 제목';
    response['actorImages'] = [
      {'name': '배우 A', 'imageUrl': 'https://example.com/actor.png'},
    ];
    return service.parse(jsonEncode(response), request);
  }

  test(
    'selected actor image is validated, stored locally, and backed up with metadata',
    () async {
      final result = await proposal();
      await service.loadActorImage(result.actorImages.single);
      expect(result.actorImages.single.error, isNull);
      await service.apply(
        result,
        {
          1: {'actors'},
        },
        selectedImages: {'배우 A'},
      );
      final actor = (await library.entities('actors')).single;
      expect(await File(actor['image'] as String).exists(), isTrue);
      expect((await library.db.query('media')).single['title'], '영상');
      expect(await service.load(), isNull);
      expect(
        root.listSync().whereType<File>().any(
          (f) => f.path.contains('before-ai-metadata'),
        ),
        isTrue,
      );
    },
  );
  test('failed image download does not block selected metadata', () async {
    service = MetadataExchange(
      library,
      imageDownloader: (_) async => Uint8List.fromList([1, 2, 3]),
    );
    final result = await proposal();
    await service.loadActorImage(result.actorImages.single);
    expect(result.actorImages.single.bytes, isNull);
    expect(result.actorImages.single.error, isNotNull);
    await service.apply(result, {
      1: {'title', 'actors'},
    });
    expect((await library.db.query('media')).single['title'], '수정 제목');
    expect((await library.entities('actors')).single['image'], '');
  });
  test(
    'new actor requires actor field selection and failed transaction cleans image files',
    () async {
      final result = await proposal();
      await service.loadActorImage(result.actorImages.single);
      await expectLater(
        service.apply(
          result,
          {
            1: {'title'},
          },
          selectedImages: {'배우 A'},
        ),
        throwsStateError,
      );
      expect((await library.db.query('media')).single['title'], '영상');
      expect(await Directory('${root.path}/actor-images').list().length, 0);
      expect(await service.load(), isNotNull);
    },
  );
  test(
    'concurrently changed actor image is preserved and metadata rolls back',
    () async {
      await library.edit(1, {'actors': '배우 A'});
      final existing = File('${root.path}/previous.png');
      await existing.writeAsBytes([1]);
      await library.db.update('actors', {'image': existing.path});
      final result = await proposal();
      expect(service.encode(result.request), isNot(contains(existing.path)));
      await service.loadActorImage(result.actorImages.single);
      await library.db.update('actors', {'image': 'updated.png'});
      await expectLater(
        service.apply(
          result,
          {
            1: {'title'},
          },
          selectedImages: {'배우 A'},
        ),
        throwsStateError,
      );
      expect((await library.entities('actors')).single['image'], 'updated.png');
      expect(await existing.exists(), isTrue);
      expect((await library.db.query('media')).single['title'], '영상');
      expect(await Directory('${root.path}/actor-images').list().length, 0);
    },
  );
  test(
    'unrelated actors, duplicate actors and non-HTTPS image URLs are rejected',
    () async {
      final result = await proposal();
      final response = jsonDecode(service.encode(result.request));
      response['videos'][0]['actors'] = ['배우 A'];
      for (final images in [
        [
          {'name': '다른 배우', 'imageUrl': 'https://example.com/a.png'},
        ],
        [
          {'name': '배우 A', 'imageUrl': 'file:///private.png'},
        ],
        List.filled(2, {
          'name': '배우 A',
          'imageUrl': 'https://example.com/a.png',
        }),
      ]) {
        response['actorImages'] = images;
        expect(
          () => service.parse(jsonEncode(response), result.request),
          throwsFormatException,
        );
      }
      await expectLater(
        downloadActorImage('https://127.0.0.1/a.png'),
        throwsFormatException,
      );
    },
  );
}
