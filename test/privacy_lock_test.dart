import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:cryptography/cryptography.dart';
import 'package:soft_vault/library.dart';
import 'package:soft_vault/privacy_lock.dart';

void main() {
  late Directory root;
  late PrivacyLock lock;
  var clock = DateTime.utc(2026, 11, 8);
  const password = 'private test password 123';
  test(
    'native password derivation matches the portable PBKDF2 implementation',
    () async {
      final salt = List<int>.generate(32, (i) => i);
      const value = '비밀번호 🔒 portable';
      final reference = await Pbkdf2.hmacSha256(
        iterations: PrivacyLock.iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: value, nonce: salt);
      expect(
        await PrivacyLock.derive(value, salt),
        await reference.extractBytes(),
      );
    },
  );
  setUp(() async {
    root = await Directory(
      await Directory.systemTemp.resolveSymbolicLinks(),
    ).createTemp('vault-privacy-unit-');
    clock = DateTime.utc(2026, 11, 8);
    lock = PrivacyLock(p.join(root.path, 'privacy.sqlite'), now: () => clock);
  });
  tearDown(() async {
    await lock.close();
    await root.delete(recursive: true);
  });

  test(
    'new install requires a setup choice; configured lock cannot be skipped',
    () async {
      expect((await lock.status()).configured, isFalse);
      await lock.deferSetup();
      expect((await lock.status()).enabled, isFalse);
      expect((await lock.status()).configured, isTrue);
      await lock.setPassword(password);
      await expectLater(lock.deferSetup(), throwsStateError);
      expect((await lock.status()).enabled, isTrue);
    },
  );

  test(
    'salted verifier persists across restarts without plaintext password',
    () async {
      expect(await lock.setPassword(password), isTrue);
      final row = (await (await lock.database).query('app_lock')).single;
      expect(row['iterations'], 600000);
      expect(base64Decode(row['salt'] as String).length, 32);
      expect(base64Decode(row['verifier'] as String).length, 32);
      await lock.close();
      expect(
        utf8.decode(await File(lock.path).readAsBytes(), allowMalformed: true),
        isNot(contains(password)),
      );
      expect(await lock.authenticate('wrong password'), isFalse);
      expect(await lock.authenticate(password), isTrue);
      final other = PrivacyLock(p.join(root.path, 'other.sqlite'));
      try {
        await other.setPassword(password);
        final second = (await (await other.database).query('app_lock')).single;
        expect(second['salt'], isNot(row['salt']));
        expect(second['verifier'], isNot(row['verifier']));
      } finally {
        await other.close();
      }
    },
  );

  test('wrong current password cannot change or disable protection', () async {
    await lock.setPassword(password);
    expect(
      await lock.setPassword('replacement password', current: 'incorrect'),
      isFalse,
    );
    expect(await lock.disable('incorrect'), isFalse);
    expect(await lock.authenticate(password), isTrue);
    expect(
      await lock.setPassword('replacement password', current: password),
      isTrue,
    );
    expect(await lock.authenticate(password), isFalse);
    expect(await lock.authenticate('replacement password'), isTrue);
    expect(await lock.disable('replacement password'), isTrue);
    await lock.close();
    expect((await lock.status()).enabled, isFalse);
  });

  test(
    'failed attempts commit, survive restart and enforce a cooldown',
    () async {
      await lock.setPassword(password);
      for (var i = 0; i < 5; i++) {
        expect(await lock.authenticate('wrong'), isFalse);
      }
      await lock.close();
      expect(
        (await lock.status()).retryAfter,
        clock.millisecondsSinceEpoch + 30000,
      );
      await expectLater(
        lock.authenticate(password),
        throwsA(isA<PrivacyDelay>()),
      );
      clock = clock.add(const Duration(seconds: 31));
      expect(await lock.authenticate(password), isTrue);
      expect((await lock.status()).retryAfter, 0);
    },
  );

  test('concurrent failures cannot bypass the attempt threshold', () async {
    await lock.setPassword(password);
    final results = await Future.wait(
      List.generate(6, (_) async {
        try {
          return await lock.authenticate('wrong') ? 'success' : 'wrong';
        } on PrivacyDelay {
          return 'delayed';
        }
      }),
    );
    expect(results.where((r) => r == 'wrong').length, 5);
    expect(results.where((r) => r == 'delayed').length, 1);
  });

  test('malformed or missing lock records fail closed', () async {
    await lock.setPassword(password);
    final db = await lock.database;
    await db.update('app_lock', {'verifier': 'broken'});
    await expectLater(lock.status(), throwsFormatException);
    await expectLater(lock.authenticate(password), throwsFormatException);
    await db.delete('app_lock');
    await expectLater(lock.status(), throwsFormatException);
  });

  test('catalog backup/restore cannot export or remove the app lock', () async {
    final library = await Library.open(p.join(root.path, 'catalog.sqlite'));
    try {
      final backup = File(p.join(root.path, 'backup.json'));
      await library.exportTo(backup);
      await lock.setPassword(password);
      await library.restoreFrom(backup);
      expect((await lock.status()).enabled, isTrue);
      final text = await backup.readAsString();
      expect(text, isNot(contains('verifier')));
      expect(text, isNot(contains(password)));
      expect(await lock.authenticate(password), isTrue);
    } finally {
      await library.close();
    }
  });

  test('password length bounds and Unicode are supported', () async {
    expect(PrivacyLock.validatePassword('short'), isNotNull);
    expect(PrivacyLock.validatePassword(' ' * 8), isNotNull);
    expect(PrivacyLock.validatePassword('a' * 129), isNotNull);
    const unicode = '비밀 영상 🔒 123';
    expect(await lock.setPassword(unicode), isTrue);
    expect(await lock.authenticate(unicode), isTrue);
    expect(await lock.authenticate('$unicode '), isFalse);
  });
}
