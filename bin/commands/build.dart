import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../tasks/dependency/check_depencies.dart' as dependencies;
import '../tasks/util.dart';

enum BuildTarget { debug, profile, release }

const targetExec = 'veshell';

class BuildCommand extends Command<int> {
  BuildCommand({required this.logger}) {
    argParser.addOption(
      'target',
      abbr: 't',
      help: 'Specify the build target',
      allowed: BuildTarget.values.map((e) => e.name),
    );
  }

  final Logger logger;
  @override
  final name = 'build';
  @override
  final description = 'Build and package Veshell';

  // [run] may also return a Future.
  @override
  Future<int> run() async {
    final targetString = argResults?['target'] as String?;
    final target = BuildTarget.values.byName(targetString ?? 'debug');
    await dependencies.check(logger);
    await buildAll(logger, target: target);
    return ExitCode.success.code;
  }
}

Future<void> buildAll(
  Logger logger, {
  BuildTarget target = BuildTarget.debug,
}) async {
  await buildEmbedder(logger);
  await buildShell(logger);
  await packageBuild(logger);
}

Future<void> buildEmbedder(
  Logger logger, {
  BuildTarget target = BuildTarget.debug,
}) async {
  logger.info('Building the rust embedder in ${target.name}...\n');
  final exitCode = await runProcess(
    'cargo',
    ['build', '--color', 'always'],
    workingDirectory: 'embedder',
    environment: {'FLUTTER_ENGINE_BUILD': target.name},
  );
  if (exitCode != 0) {
    exit(exitCode);
  }
  logger.success('Build completed\n');
}

Future<void> buildShell(
  Logger logger, {
  BuildTarget target = BuildTarget.debug,
}) async {
  logger.info('Building the shell in ${target.name}...\n');
  var exitCode = await runProcess(
    'dart',
    [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
    ],
    workingDirectory: 'shell',
    environment: {'FORCE_COLOR': 'true'},
  );

  if (exitCode != 0) {
    exit(exitCode);
  }

  exitCode = await runProcess(
    'flutter',
    [
      'build',
      'linux',
      '--${target.name}',
    ],
    workingDirectory: 'shell',
    environment: {'FORCE_COLOR': 'true'},
  );
  if (exitCode != 0) {
    exit(exitCode);
  }
  logger.success('Build completed\n');
}

Future<void> packageBuild(
  Logger logger, {
  BuildTarget target = BuildTarget.debug,
}) async {
  logger.info('Packaging build...\n');

  final unameM = (await Process.run('uname', ['-m'])).stdout as String;

  var arch = '';

  if (unameM.contains('x86_64') == true) {
    arch = 'x64';
  } else {
    arch = 'arm64';
  }

  final buildDirectory = 'build/${target.name}';
  logger.info('Create $buildDirectory directory');
  await Directory('$buildDirectory/lib/').create(recursive: true);

  final binaryPath = 'embedder/target/${target.name}/$targetExec';
  logger.info('Copy $binaryPath');
  await File(binaryPath).copy('$buildDirectory/$targetExec');

  final libFlutterEnginePath =
      'embedder/third_party/flutter_engine/${target.name}/libflutter_engine.so';

  logger.info('Copy $libFlutterEnginePath');
  await File(libFlutterEnginePath)
      .copy('$buildDirectory/lib/libflutter_engine.so');

  await runProcess(
    'cp',
    ['-r', 'shell/build/linux/$arch/debug/bundle/data', buildDirectory],
  );

  logger.success('\nPackaging completed\n');
}
