import 'advanced_catalog.dart';
import 'file_jobs.dart';
import 'library.dart';

class RuleRunner {
  final Library library;
  final FileJobs jobs;
  RuleRunner(this.library, this.jobs);
  Future<List<Map<String, Object?>>> preview(Map<String, Object?> rule) async =>
      (await library.matching(
        MediaCriteria.decode(rule['criteria'] as String),
      )).where((row) => row['online'] == 1).toList();
  Future<void> run(
    Map<String, Object?> rule, {
    bool automatic = false,
    Set<int>? visited,
  }) async {
    final candidates = await preview(rule);
    for (final row in candidates) {
      final id = row['id'] as int;
      if (visited?.contains(id) ?? false) continue;
      final key = 'rule_attempt:${rule['id']}:$id';
      final signature =
          '${rule['updated']}:${row['path']}:${row['fingerprint']}:${row['modified']}';
      if (automatic && await library.readSetting(key) == signature) continue;
      await jobs.move(
        [id],
        rule['destination'] as String,
        autoRename: rule['auto_rename'] == 1,
      );
      await library.setting(key, signature);
      visited?.add(id);
    }
  }

  Future<void> runAutomatic({Set<int> skipIds = const {}}) async {
    if (jobs.running) return;
    final visited = <int>{...skipIds};
    for (final rule in await library.moveRules()) {
      if (rule['enabled'] == 1)
        await run(rule, automatic: true, visited: visited);
    }
  }
}
