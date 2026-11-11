import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../lib/update_protocol.dart';

Future<bool> alive(int id) async {
  final result = Platform.isWindows
      ? await Process.run('tasklist', [
          '/FI',
          'PID eq $id',
          '/FO',
          'CSV',
          '/NH',
        ])
      : await Process.run('/bin/kill', ['-0', '$id']);
  return Platform.isWindows
      ? result.stdout.toString().contains('"$id"')
      : result.exitCode == 0;
}

Future<void> main(List<String> args) async {
  final root = Directory(args[0]),
      target = Directory(args[1]),
      data = Directory(args[2]);
  final oldPid = int.parse(args[3]);
  if (!p.isAbsolute(target.path) ||
      target.path == p.dirname(target.path) ||
      p.isWithin(target.path, data.path) ||
      target.path == data.path ||
      !p.isWithin(data.path, root.path)) {
    throw StateError('Unsafe update directories');
  }
  final lock = await File(
    p.join(root.path, 'helper.lock'),
  ).open(mode: FileMode.append);
  await lock.lock(FileLock.exclusive);
  final backup = Directory('${target.path}.previous');
  final stage = Directory('${target.path}.update-stage');
  final snapshot = Directory(p.join(root.path, 'database-backup'));
  final journal = File(p.join(root.path, 'transaction.json'));
  final health = File(p.join(root.path, 'healthy'));
  var replaced = false;
  var phase = 'waiting';
  Future<void> retryFile(Future<void> Function() action) async {
    for (var attempt = 0; ; attempt++) {
      try {
        await action();
        return;
      } on FileSystemException {
        if (attempt >= 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  Process? child;
  Future<void> record(String state) => journal
      .writeAsString(
        jsonEncode({
          'state': state,
          'target': target.path,
          'data': data.path,
          'childPid': child?.pid,
        }),
        flush: true,
      )
      .then((_) {});
  Future<void> launch({bool check = false}) async {
    final exe = Platform.isWindows
        ? p.join(target.path, 'soft_vault.exe')
        : p.join(target.path, 'Contents', 'MacOS', 'Soft Vault');
    child = await Process.start(
      exe,
      check ? ['--update-ready', health.path] : [],
      workingDirectory: root.path,
    );
    unawaited(child!.stdout.drain<void>());
    unawaited(child!.stderr.drain<void>());
  }

  try {
    for (var i = 0; await alive(oldPid); i++) {
      if (i >= 120) throw StateError('App did not exit');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (await journal.exists()) {
      final prior = jsonDecode(await journal.readAsString());
      final state = prior['state'];
      if (args.contains('--recover') &&
          (state == 'complete' || state == 'rolledBack'))
        return;
      if (state != 'complete' && state != 'rolledBack') {
        if (prior['childPid'] is int && await alive(prior['childPid'])) {
          // Never restore a database underneath a running application.
          if (await health.exists()) await record('complete');
          return;
        }
        replaced = await backup.exists();
        throw StateError('Recover interrupted transaction');
      }
    }
    phase = 'verify';
    final manifest = await verifyManifest(
      await File(p.join(root.path, 'update.json')).readAsBytes(),
      await File(p.join(root.path, 'update.json.sig')).readAsString(),
      args[4],
    );
    final asset =
        manifest['platforms'][Platform.isWindows
                ? 'windows-x64'
                : 'macos-arm64']
            as Map<String, dynamic>;
    final zip = File(p.join(root.path, 'package.zip'));
    await verifyPackage(zip, asset);
    phase = 'extract';
    if (await stage.exists()) await stage.delete(recursive: true);
    await stage.create();
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final prefix = Platform.isWindows
        ? 'SoftVault-Windows/app/'
        : 'SoftVault-macOS-arm64/Soft Vault.app/';
    final links = <ArchiveFile>[];
    for (final entry in archive) {
      final name = entry.name.replaceAll('\\', '/');
      if (name.startsWith('/') ||
          name.split('/').contains('..') ||
          name.contains(':'))
        throw const FormatException('Unsafe archive path');
      if (!name.startsWith(prefix)) continue;
      final relative = name.substring(prefix.length);
      if (relative.isEmpty) continue;
      final destination = p.join(stage.path, relative);
      if (!p.isWithin(stage.path, p.normalize(destination)))
        throw const FormatException('Unsafe archive path');
      if (entry.isSymbolicLink) {
        final link = entry.symbolicLink!;
        if (p.isAbsolute(link) ||
            !p.isWithin(
              stage.path,
              p.normalize(p.join(p.dirname(destination), link)),
            ))
          throw const FormatException('Unsafe link');
        links.add(entry);
        continue;
      }
      if (entry.isFile) {
        final file = File(destination);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.content);
        if (!Platform.isWindows)
          await Process.run('/bin/chmod', [
            (entry.unixPermissions & 0x1ff).toRadixString(8),
            destination,
          ]);
      } else {
        await Directory(destination).create(recursive: true);
      }
    }
    for (final entry in links) {
      final link = Link(
        p.join(stage.path, entry.name.substring(prefix.length)),
      );
      await link.parent.create(recursive: true);
      await link.create(entry.symbolicLink!);
    }
    final exe = Platform.isWindows
        ? p.join(stage.path, 'soft_vault.exe')
        : p.join(stage.path, 'Contents', 'MacOS', 'Soft Vault');
    if (!await File(exe).exists()) throw StateError('Incomplete package');
    phase = 'backup-database';
    if (await snapshot.exists()) await snapshot.delete(recursive: true);
    await snapshot.create();
    for (final name in ['vault.sqlite', 'privacy.sqlite']) {
      for (final suffix in ['', '-wal', '-shm']) {
        final file = File(p.join(data.path, '$name$suffix'));
        if (await file.exists())
          await file.copy(p.join(snapshot.path, '$name$suffix'));
      }
    }
    if (await health.exists()) await health.delete();
    if (await backup.exists()) await backup.delete(recursive: true);
    await record('prepared');
    phase = 'backup-application';
    await retryFile(() async {
      await target.rename(backup.path);
    });
    replaced = true;
    phase = 'install-application';
    await retryFile(() async {
      await stage.rename(target.path);
    });
    await record('installed');
    phase = 'startup-health';
    await launch(check: true);
    await record('installed');
    for (var i = 0; !await health.exists(); i++) {
      if ((i >= 90 || !await alive(child!.pid)) && !await health.exists())
        throw StateError('Startup failed');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    await record('complete');
    final oldError = File(p.join(root.path, 'last-error.txt'));
    if (await oldError.exists()) await oldError.delete();
  } catch (failure) {
    await File(
      p.join(root.path, 'failure-type.txt'),
    ).writeAsString(failure.runtimeType.toString());
    if (await alive(oldPid)) return;
    if (child != null && await alive(child!.pid)) {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '${child!.pid}', '/T', '/F']);
      } else {
        child!.kill(ProcessSignal.sigkill);
      }
    }
    if (child != null) await child!.exitCode;
    if (replaced) {
      if (await target.exists()) {
        // Windows may retain the executable image briefly after process exit.
        for (var attempt = 0; ; attempt++) {
          try {
            await target.delete(recursive: true);
            break;
          } on FileSystemException {
            if (attempt == 20) rethrow;
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
      }
      await backup.rename(target.path);
      for (final name in ['vault.sqlite', 'privacy.sqlite']) {
        for (final suffix in ['', '-wal', '-shm']) {
          final file = File(p.join(data.path, '$name$suffix'));
          if (await file.exists()) await file.delete();
          final saved = File(p.join(snapshot.path, '$name$suffix'));
          if (await saved.exists()) await saved.copy(file.path);
        }
      }
    }
    await record('rolledBack');
    await File(p.join(root.path, 'last-error.txt')).writeAsString(
      'Update failed at $phase: $failure. Previous application and database restored.',
    );
    if (await target.exists()) await launch();
  } finally {
    await lock.unlock();
    await lock.close();
  }
}
