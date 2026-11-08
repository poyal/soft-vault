import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_vault/library.dart';
import 'package:soft_vault/advanced_catalog.dart';
import 'package:soft_vault/file_jobs.dart';
import 'package:soft_vault/rule_runner.dart';
import 'package:soft_vault/nfo_service.dart';

void main() {
  late Directory root, source, target;
  late Library library;
  late int id;
  setUp(() async {
    root = await Directory(
      await Directory.systemTemp.resolveSymbolicLinks(),
    ).createTemp('vault-advanced-');
    source = await Directory(p.join(root.path, '원본')).create();
    target = await Directory(p.join(root.path, '정리')).create();
    await File(p.join(source.path, '여행.mp4')).writeAsBytes([1, 2, 3]);
    library = await Library.open(p.join(root.path, 'db.sqlite'));
    await library.connect(source.path);
    await library.connect(target.path);
    id = (await library.items()).single['id'] as int;
    await library.edit(id, {
      'tags': '여행, 자연',
      'actors': '이서윤',
      'rating': 4,
      'note': '개인 메모',
    });
    await library.db.update(
      'media',
      {'duration': 60, 'resolution': '1920 × 1080'},
      where: 'id=?',
      whereArgs: [id],
    );
  });
  tearDown(() async {
    await library.close();
    await root.delete(recursive: true);
  });
  test('v2 SQLite migrates in place without losing metadata', () async {
    for (final table in ['bookmarks', 'collections', 'move_rules']) {
      await library.db.execute('DROP TABLE $table');
    }
    for (final column in [
      'resume_ms',
      'watched',
      'last_played',
      'custom_thumbnail',
    ]) {
      await library.db.execute('ALTER TABLE media DROP COLUMN $column');
    }
    await library.db.execute('PRAGMA user_version=2');
    await library.close();
    library = await Library.open(p.join(root.path, 'db.sqlite'));
    expect(
      (await library.db.rawQuery('PRAGMA user_version')).single.values.single,
      3,
    );
    expect((await library.mediaById(id))['note'], '개인 메모');
    expect((await library.mediaById(id))['resume_ms'], 0);
    await library.saveBookmark(
      id,
      const Duration(seconds: 3),
      title: '업그레이드 후',
    );
    expect((await library.bookmarks(id)).length, 1);
  });

  test(
    'resume and bookmarks survive move, reopen and backup restore',
    () async {
      await library.saveResume(
        id,
        const Duration(seconds: 17),
        const Duration(seconds: 60),
      );
      final mark = await library.saveBookmark(
        id,
        const Duration(seconds: 12),
        title: '첫 장면',
        note: '한글 & <메모> 🎬',
      );
      await FileJobs(library).move([id], target.path, forceCopy: true);
      await library.close();
      library = await Library.open(p.join(root.path, 'db.sqlite'));
      expect((await library.mediaById(id))['resume_ms'], 17000);
      expect((await library.bookmarks(id)).single['note'], '한글 & <메모> 🎬');
      final backup = File(p.join(root.path, 'backup.json'));
      await library.exportTo(backup);
      await library.deleteBookmark(mark);
      await library.saveResume(
        id,
        const Duration(seconds: 60),
        const Duration(seconds: 60),
      );
      expect((await library.mediaById(id))['watched'], 1);
      expect((await library.mediaById(id))['resume_ms'], 0);
      await library.restoreFrom(backup);
      expect((await library.bookmarks(id)).single['id'], mark);
      expect((await library.mediaById(id))['resume_ms'], 17000);
      await library.saveResume(
        id,
        const Duration(seconds: -2),
        const Duration(seconds: 60),
      );
      expect((await library.mediaById(id))['resume_ms'], 0);
    },
  );
  test(
    'saved collection evaluates exact AND tags, aliases and resume dynamically',
    () async {
      await library.db.update('actors', {'alias': '서윤, SY'});
      const criteria = MediaCriteria(
        tags: '여행, 자연',
        actor: 'SY',
        minimumRating: 4,
        unfinished: true,
      );
      await library.saveCollection('이어서 볼 여행', criteria);
      expect(await library.matching(criteria), isEmpty);
      await library.saveResume(
        id,
        const Duration(seconds: 5),
        const Duration(seconds: 60),
      );
      expect((await library.matching(criteria)).single['id'], id);
      await library.edit(id, {'tags': '여행기, 자연'});
      expect(await library.matching(criteria), isEmpty);
      expect(
        MediaCriteria.decode(
          (await library.collections()).single['criteria'] as String,
        ).actor,
        'SY',
      );
    },
  );
  test(
    'rules preview, opt-in automation, skip playing and reject cycles',
    () async {
      final jobs = FileJobs(library),
          runner = RuleRunner(library, FileJobs(library));
      final ruleId = await library.saveMoveRule(
        '여행 정리',
        MediaCriteria(folder: source.path, tags: '여행'),
        target.path,
      );
      var rule = (await library.moveRules()).single;
      expect((await runner.preview(rule)).length, 1);
      await runner.runAutomatic();
      expect((await library.mediaById(id))['folder'], source.path);
      await library.saveMoveRule(
        '여행 정리',
        MediaCriteria(folder: source.path, tags: '여행'),
        target.path,
        id: ruleId,
        enabled: true,
      );
      await expectLater(
        library.saveMoveRule(
          '순환',
          MediaCriteria(folder: target.path),
          source.path,
          enabled: true,
        ),
        throwsArgumentError,
      );
      await runner.runAutomatic(skipIds: {id});
      expect((await library.mediaById(id))['folder'], source.path);
      rule = (await library.moveRules()).single;
      await runner.run(rule);
      expect((await library.mediaById(id))['folder'], target.path);
      expect((await jobs.history()).single['state'], 'done');
      expect((await library.mediaById(id))['note'], '개인 메모');
    },
  );
  test(
    'automatic collision is recorded once and never replaces file',
    () async {
      await File(p.join(target.path, '여행.mp4')).writeAsString('keep');
      await library.saveMoveRule(
        '규칙',
        MediaCriteria(folder: source.path),
        target.path,
        enabled: true,
      );
      final jobs = FileJobs(library),
          runner = RuleRunner(library, FileJobs(library));
      await runner.runAutomatic();
      await runner.runAutomatic();
      expect((await jobs.history()).length, 1);
      expect(await File(p.join(target.path, '여행.mp4')).readAsString(), 'keep');
    },
  );
  test(
    'duplicates distinguish exact content from similar metadata and recheck bytes',
    () async {
      final copy = await File(
        p.join(source.path, '여행.mp4'),
      ).copy(p.join(source.path, '복사.mp4'));
      await library.scan(source.path);
      final group = (await library.duplicateGroups()).single;
      final other = group.firstWhere((row) => row['id'] != id)['id'] as int;
      expect(await library.verifyDuplicate(id, other), isTrue);
      await copy.writeAsBytes([4, 5, 6, 7]);
      await library.scan(source.path);
      await library.db.update('media', {
        'duration': 60,
        'resolution': '1920 × 1080',
      });
      expect(await library.verifyDuplicate(id, other), isFalse);
      expect(await library.duplicateGroups(), isEmpty);
      expect((await library.duplicateGroups(similar: true)).length, 1);
      expect(await copy.exists(), isTrue);
    },
  );
  test(
    'NFO escapes Unicode, roundtrips resume/bookmarks, imports idempotently',
    () async {
      await library.edit(id, {
        'title': '한글 & <여행> 🎬',
        'description': '첫 줄\n둘째 줄',
        'rating': 5,
      });
      await library.saveResume(
        id,
        const Duration(milliseconds: 12345),
        const Duration(seconds: 60),
      );
      await library.saveBookmark(
        id,
        const Duration(milliseconds: 9001),
        title: '장면 <1>',
        note: '& 메모',
      );
      final nfo = NfoService(library),
          encoded = await NfoService(library).encode(id);
      expect(encoded, contains('&amp;'));
      expect(encoded, contains('&lt;여행>'));
      final data = nfo.parse(encoded);
      expect(data.fields['description'], '첫 줄\n둘째 줄');
      await nfo.apply(id, data);
      await nfo.apply(id, data);
      expect((await library.bookmarks(id)).length, 1);
      expect((await library.mediaById(id))['resume_ms'], 12345);
      expect((await library.mediaById(id))['title'], '한글 & <여행> 🎬');
      await nfo.apply(
        id,
        nfo.parse('<episodedetails><plot>새 설명</plot></episodedetails>'),
      );
      expect((await library.mediaById(id))['note'], '개인 메모');
      expect((await library.mediaById(id))['rating'], 5);
      final output = File(p.join(root.path, 'movie.nfo'));
      await nfo.write(id, output);
      final original = await output.readAsString();
      await expectLater(
        nfo.write(id, output),
        throwsA(isA<FileSystemException>()),
      );
      await library.edit(id, {'title': '변경'});
      await nfo.write(id, output, overwrite: true);
      final backup =
          (await root
                      .list()
                      .where((file) => file.path.contains('.backup-'))
                      .toList())
                  .single
              as File;
      expect(await backup.readAsString(), original);
      expect(nfo.parse(await output.readAsString()).fields['title'], '변경');
    },
  );
  test('NFO rejects DTD, malformed and invalid timing', () {
    final nfo = NfoService(library);
    for (final xml in [
      '<!DOCTYPE movie [<!ENTITY x SYSTEM "file:///secret">]><movie/>',
      '<bad/>',
      '<movie>',
      '<movie><resume><position>-1</position></resume></movie>',
      '<movie><softvault><bookmark seconds="NaN"><title>x</title></bookmark></softvault></movie>',
    ]) {
      expect(() => nfo.parse(xml), throwsA(anything));
    }
  });
  test('v2 JSON backups acquire defaults for all new fields', () async {
    final file = File(p.join(root.path, 'legacy.json'));
    await library.exportTo(file);
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    data['version'] = 2;
    for (final key in ['bookmarks', 'collections', 'move_rules']) {
      data.remove(key);
    }
    for (final row in data['media'] as List) {
      for (final key in [
        'resume_ms',
        'watched',
        'last_played',
        'custom_thumbnail',
      ]) {
        (row as Map).remove(key);
      }
    }
    await file.writeAsString(jsonEncode(data));
    await library.restoreFrom(file);
    expect((await library.mediaById(id))['resume_ms'], 0);
    expect(await library.bookmarks(id), isEmpty);
    expect((await library.mediaById(id))['tags'], '여행, 자연');
  });
}
