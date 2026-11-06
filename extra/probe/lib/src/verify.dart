import 'dart:io';

import 'package:path/path.dart' as p;

/// One step of `verify`.
class VerifyStep {
  const VerifyStep(this.name, this.executable, this.arguments, this.directory);

  final String name;
  final String executable;
  final List<String> arguments;

  /// Relative to the repository root.
  final String directory;
}

/// The checks a change must pass (see `AGENTS.md`), in order.
List<VerifyStep> verifySteps(
  String repositoryRoot, {
  bool rust = true,
  bool dart = true,
}) {
  final sdk = p.join(repositoryRoot, '.flutter_sdk', 'bin');
  return [
    if (rust) ...[
      // Builds the Dart side as well (see AGENTS.md: a single gate).
      const VerifyStep('cargo check', 'cargo', ['check'], '.'),
      const VerifyStep('cargo fmt', 'cargo', ['fmt', '--check'], '.'),
      const VerifyStep('cargo test', 'cargo', ['test'], '.'),
    ],
    if (dart) ...[
      VerifyStep('dart format', p.join(sdk, 'dart'), [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        'lib',
        'test',
      ], 'src/shell'),
      VerifyStep('flutter test', p.join(sdk, 'flutter'), [
        'test',
        '--reporter',
        'expanded',
      ], 'src/shell'),
      // The probe itself: its own package, outside the shell's gate, and
      // resolved here so the steps below never depend on an earlier run.
      VerifyStep('probe pub get', p.join(sdk, 'dart'), [
        'pub',
        'get',
      ], 'extra/probe'),
      VerifyStep('probe format', p.join(sdk, 'dart'), [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        'bin',
        'lib',
        'test',
      ], 'extra/probe'),
      VerifyStep('probe analyze', p.join(sdk, 'dart'), [
        'analyze',
      ], 'extra/probe'),
      VerifyStep('probe test', p.join(sdk, 'dart'), ['test'], 'extra/probe'),
    ],
  ];
}

/// The failing tests in an expanded `flutter test` report, as
/// `<file relative to test/>: <test name>`.
Set<String> failingTests(String report) {
  final failures = <String>{};
  final line = RegExp(r'^\d+:\d+ \+\d+(?: ~\d+)? -\d+: (.*) \[E\]$');
  for (final raw in report.split('\n')) {
    final match = line.firstMatch(raw.trimRight());
    if (match == null) {
      continue;
    }
    var name = match.group(1)!;
    // A test file that fails to load (does not compile).
    if (name.startsWith('loading ')) {
      failures.add('loading ${p.basename(name.substring('loading '.length))}');
      continue;
    }
    final testDirectory = name.indexOf('/test/');
    if (testDirectory >= 0) {
      name = name.substring(testDirectory + '/test/'.length);
    }
    failures.add(name);
  }
  return failures;
}

/// The known failures listed in [file]: one per line, `#` for comments.
Set<String> readKnownFailures(File file) {
  if (!file.existsSync()) {
    return {};
  }
  return {
    for (final line in file.readAsLinesSync())
      if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
        line.trim(),
  };
}

/// Runs [steps] from [repositoryRoot]; the Flutter tests are compared with
/// [knownFailures].
Future<Map<String, Object?>> verify(
  String repositoryRoot, {
  required List<VerifyStep> steps,
  required Set<String> knownFailures,
  void Function(String message)? progress,
}) async {
  final results = <Map<String, Object?>>[];
  var ok = true;
  Map<String, Object?>? flutter;
  for (final step in steps) {
    progress?.call('${step.name}…');
    final clock = Stopwatch()..start();
    final result = await Process.run(
      step.executable,
      step.arguments,
      workingDirectory: p.join(repositoryRoot, step.directory),
    );
    final output = '${result.stdout}\n${result.stderr}';
    var stepOk = result.exitCode == 0;
    final entry = <String, Object?>{
      'step': step.name,
      'exitCode': result.exitCode,
      'seconds': clock.elapsed.inSeconds,
    };
    if (step.name == 'flutter test') {
      final failing = failingTests(output);
      final introduced = failing.difference(knownFailures).toList()..sort();
      final fixed = knownFailures.difference(failing).toList()..sort();
      // The suite exits non-zero on the known failures: only new ones count.
      stepOk =
          introduced.isEmpty && (result.exitCode == 0 || failing.isNotEmpty);
      flutter = {
        'failing': failing.length,
        'newFailures': introduced,
        'knownFailuresNowPassing': fixed,
      };
      entry.addAll(flutter);
    }
    entry['ok'] = stepOk;
    if (!stepOk) {
      entry['outputTail'] = output
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList()
          .reversed
          .take(40)
          .toList()
          .reversed
          .join('\n');
    }
    ok &= stepOk;
    results.add(entry);
  }
  return {'ok': ok, 'steps': results};
}
