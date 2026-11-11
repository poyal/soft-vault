import 'package:soft_vault/settings_components.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_vault/actor_images.dart';
import 'package:soft_vault/library.dart';

void main() {
  for (final embedded in [false, true])
    testWidgets(
      'image cancel, invalid replacement and removal preserve actor metadata embedded=$embedded',
      (tester) async {
        final dir = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('actor-images-'),
        ))!;
        final library = (await tester.runAsync(
          () => Library.open(dir.path + '/db.sqlite'),
        ))!;
        final image = File('design/assets/forest.jpg').absolute.path;
        await tester.runAsync(
          () => library.saveActor(
            name: '배우',
            alias: '별명',
            image: image,
            description: '설명',
          ),
        );
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SettingsSection(
                    title: '배우 이미지',
                    children: [
                      ActorImages(library: library, embeddedEditor: embedded),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          await tester.tap(find.text('배우'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('이미지 제거'));
          await tester.tap(find.text('취소'));
          await tester.pumpAndSettle();
          expect(
            (await tester.runAsync(
              () => library.entities('actors'),
            ))!.single['image'],
            image,
          );
          await tester.tap(find.text('배우'));
          await tester.pumpAndSettle();
          tester
                  .widget<ActorImagePicker>(find.byType(ActorImagePicker))
                  .controller
                  .text =
              'missing.png';
          await tester.pumpAndSettle();
          await tester.tap(find.text('저장'));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          expect(
            (await tester.runAsync(
              () => library.entities('actors'),
            ))!.single['image'],
            image,
          );
          await tester.tap(find.text('배우'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('이미지 제거'));
          await tester.tap(find.text('저장'));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          final row = (await tester.runAsync(
            () => library.entities('actors'),
          ))!.single;
          expect(row['image'], '');
          expect(row['alias'], '별명');
          expect(row['description'], '설명');
          expect(await tester.runAsync(() => File(image).exists()), isTrue);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(library.close);
          await tester.runAsync(() => dir.delete(recursive: true));
        }
      },
    );
}
