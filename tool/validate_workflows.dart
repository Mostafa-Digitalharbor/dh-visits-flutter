// Parses every .github/workflows/*.yml and asserts the structural invariants
// this pipeline depends on. A YAML typo or a mis-indented `run: |` block is
// otherwise only discovered by pushing and burning a CI round-trip.
//
//   dart run tool/validate_workflows.dart
import 'dart:io';

import 'package:yaml/yaml.dart';

void main() {
  final dir = Directory('.github/workflows');
  if (!dir.existsSync()) {
    stderr.writeln('No .github/workflows directory.');
    exit(1);
  }

  final problems = <String>[];
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final name = file.path.replaceAll(r'\', '/');
    YamlMap doc;
    try {
      doc = loadYaml(file.readAsStringSync()) as YamlMap;
    } catch (e) {
      problems.add('$name: does not parse -- $e');
      continue;
    }

    // `on:` is the YAML 1.1 boolean `true`, which is why it round-trips as a
    // bool key rather than the string 'on'. Accept either.
    final triggers = doc['on'] ?? doc[true];
    if (triggers == null) problems.add('$name: no `on:` trigger block');

    final jobs = doc['jobs'];
    if (jobs is! YamlMap || jobs.isEmpty) {
      problems.add('$name: no jobs');
      continue;
    }

    for (final entry in jobs.entries) {
      final id = entry.key;
      final job = entry.value;
      if (job is! YamlMap) {
        problems.add('$name/$id: job is not a mapping');
        continue;
      }
      if (job['runs-on'] == null) problems.add('$name/$id: no runs-on');

      // The `secrets` context is unavailable in `jobs.<id>.if`; GitHub
      // evaluates it to empty and the job silently never runs.
      final cond = job['if']?.toString() ?? '';
      if (cond.contains('secrets.')) {
        problems.add('$name/$id: `if:` references secrets.* -- always false. '
            'Pass the decision through a job output instead.');
      }

      final steps = job['steps'];
      if (steps is! YamlList) {
        problems.add('$name/$id: steps is not a list');
        continue;
      }
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i];
        if (step is! YamlMap) {
          problems.add('$name/$id step $i: not a mapping');
          continue;
        }
        if (step['uses'] == null && step['run'] == null) {
          problems.add('$name/$id step $i: neither `uses` nor `run`');
        }
        // A `run:` that swallowed the following YAML keys because of bad
        // indentation shows up as a script containing "\n- name:".
        final run = step['run'];
        if (run is String && RegExp(r'^\s*- (name|uses|run):', multiLine: true).hasMatch(run)) {
          problems.add('$name/$id step $i: the `run:` block absorbed a '
              'following step -- indentation is wrong');
        }
      }
    }
    stdout.writeln('$name: ${(jobs).length} job(s) parsed');
  }

  if (problems.isEmpty) {
    stdout.writeln('\nAll workflows OK.');
    return;
  }
  stderr.writeln('\n${problems.length} problem(s):');
  for (final p in problems) {
    stderr.writeln('  - $p');
  }
  exit(1);
}
