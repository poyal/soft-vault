import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'privacy_crypto_windows.dart';

class PrivacyStatus {
  final bool enabled, configured;
  final int retryAfter;
  const PrivacyStatus(this.enabled, this.configured, this.retryAfter);
}

class PrivacyDelay implements Exception {
  final int seconds;
  const PrivacyDelay(this.seconds);
  @override
  String toString() => '$seconds초 후 다시 시도해 주세요.';
}

/// Separate from the catalog: exporting/restoring catalog settings cannot
/// export the verifier or disable the app lock. Transactions serialize attempts
/// and credential changes; a failed attempt must commit, not roll back.
class PrivacyLock {
  static const iterations = 600000;
  final String path;
  final DateTime Function() now;
  Future<Database>? _database;
  PrivacyLock(this.path, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  Future<Database> get database => _database ??= _open();
  Future<Database> _open() async {
    sqfliteFfiInit();
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE app_lock (
          id INTEGER PRIMARY KEY CHECK(id=1), configured INTEGER NOT NULL,
          enabled INTEGER NOT NULL, salt TEXT, verifier TEXT,
          iterations INTEGER NOT NULL, failures INTEGER NOT NULL,
          retry_after INTEGER NOT NULL)''');
          await db.insert('app_lock', {
            'id': 1,
            'configured': 0,
            'enabled': 0,
            'iterations': iterations,
            'failures': 0,
            'retry_after': 0,
          });
        },
      ),
    );
  }

  Future<Map<String, Object?>> _record(DatabaseExecutor db) async {
    final rows = await db.query('app_lock');
    if (rows.length != 1) throw const FormatException('Invalid lock record');
    final row = rows.single;
    if (row['id'] != 1 ||
        ![0, 1].contains(row['enabled']) ||
        ![0, 1].contains(row['configured']) ||
        row['iterations'] != iterations ||
        row['failures'] is! int ||
        (row['failures'] as int) < 0 ||
        row['retry_after'] is! int ||
        (row['retry_after'] as int) < 0) {
      throw const FormatException('Invalid lock record');
    }
    if (row['enabled'] == 1) {
      if (row['configured'] != 1 ||
          row['salt'] is! String ||
          row['verifier'] is! String ||
          base64Decode(row['salt'] as String).length != 32 ||
          base64Decode(row['verifier'] as String).length != 32) {
        throw const FormatException('Invalid lock verifier');
      }
    }
    return row;
  }

  Future<PrivacyStatus> status() async {
    final row = await _record(await database);
    return PrivacyStatus(
      row['enabled'] == 1,
      row['configured'] == 1,
      row['retry_after'] as int,
    );
  }

  static String? validatePassword(String password) {
    if (password.trim().isEmpty || password.runes.length < 8) {
      return '비밀번호는 8자 이상 입력해 주세요.';
    }
    if (password.runes.length > 128) return '비밀번호는 128자까지 사용할 수 있습니다.';
    return null;
  }

  static Future<List<int>> derive(String password, List<int> salt) =>
      Isolate.run(() async {
        if (Platform.isWindows)
          return deriveWindowsPassword(password, salt, iterations);
        final algorithm = Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
        final key = await algorithm.deriveKeyFromPassword(
          password: password,
          nonce: salt,
        );
        return key.extractBytes();
      });

  Future<bool> _verify(
    Transaction tx,
    Map<String, Object?> row,
    String password,
  ) async {
    if (row['enabled'] != 1) return true;
    final remaining =
        (row['retry_after'] as int) - now().millisecondsSinceEpoch;
    if (remaining > 0) throw PrivacyDelay((remaining / 1000).ceil());
    final candidate = await derive(
      password,
      base64Decode(row['salt'] as String),
    );
    // Hash equality uses cryptography's constant-time byte comparison.
    final matches =
        Hash(candidate) == Hash(base64Decode(row['verifier'] as String));
    final failures = matches ? 0 : (row['failures'] as int) + 1;
    final seconds = failures < 5
        ? 0
        : min(300, 30 * pow(2, min(failures - 5, 4))).toInt();
    await tx.update('app_lock', {
      'failures': failures,
      'retry_after': seconds == 0
          ? 0
          : now().millisecondsSinceEpoch + seconds * 1000,
    }, where: 'id=1');
    return matches;
  }

  Future<bool> authenticate(String password) async =>
      (await database).transaction((tx) async {
        return _verify(tx, await _record(tx), password);
      });

  Future<bool> setPassword(String password, {String current = ''}) async {
    final error = validatePassword(password);
    if (error != null) throw ArgumentError(error);
    return (await database).transaction((tx) async {
      final row = await _record(tx);
      if (!await _verify(tx, row, current)) return false;
      final random = Random.secure();
      final salt = List<int>.generate(32, (_) => random.nextInt(256));
      final verifier = await derive(password, salt);
      await tx.update('app_lock', {
        'configured': 1,
        'enabled': 1,
        'salt': base64Encode(salt),
        'verifier': base64Encode(verifier),
        'iterations': iterations,
        'failures': 0,
        'retry_after': 0,
      }, where: 'id=1');
      return true;
    });
  }

  Future<bool> disable(String current) async =>
      (await database).transaction((tx) async {
        final row = await _record(tx);
        if (!await _verify(tx, row, current)) return false;
        await tx.update('app_lock', {
          'configured': 1,
          'enabled': 0,
          'salt': null,
          'verifier': null,
          'failures': 0,
          'retry_after': 0,
        }, where: 'id=1');
        return true;
      });

  /// The initial "later" choice can never turn an existing lock off.
  Future<void> deferSetup() async => (await database).transaction((tx) async {
    final row = await _record(tx);
    if (row['enabled'] == 1 || row['configured'] == 1) {
      throw StateError('Initial setup has already completed');
    }
    await tx.update('app_lock', {'configured': 1}, where: 'id=1');
  });

  Future<void> close() async {
    if (_database != null) await (await _database!).close();
    _database = null;
  }
}
