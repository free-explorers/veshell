import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../util.dart';
import '../veshell.dart';
import 'dependency/check_depencies.dart' as dependencies;

const targetExec = 'veshell';

class BuildCommand extends Command<int> {
  BuildCommand({required this.logger}) {
    argParser.addFlag('bundle');
  }

  final Logger logger;
  @override
  final name = 'build';
  @override
  final description = 'Build and package Veshell';

  // [run] may also return a Future.
  @override
  Future<int> run() async {
    final target =
        BuildTarget.values.byName(globalResults?['target'] as String);
    await dependencies.check(logger);
    await buildEmbedder(logger, target: target);
    await buildShell(logger, target: target);
    return ExitCode.success.code;
  }

  Future<void> buildEmbedder(
    Logger logger, {
    required BuildTarget target,
  }) async {
    logger.info('Building the rust embedder in ${target.name}...\n');

    final cargoArgs = ['build', '--color', 'always'];
    if (target != BuildTarget.debug) {
      // Profile mode does not exist in Cargo by default.
      // Just compile in release mode instead.
      cargoArgs.add('--release');
    }

    final exitCode = await runProcess(
      'cargo',
      cargoArgs,
      workingDirectory: 'embedder',
      environment: {
        if (argResults!.flag('bundle')) 'BUNDLE': 'true',
        'FLUTTER_ENGINE_BUILD': target.name,
        'RUST_LOG': logger.level == Level.verbose ? 'debug' : 'warn',
      },
    );
    if (exitCode != 0) {
      exit(exitCode);
    }
    logger.success('Build completed\n');
  }

  Future<void> buildShell(
    Logger logger, {
    required BuildTarget target,
  }) async {
    logger.info('Building the shell in ${target.name}...\n');
    var exitCode = await (await Process.start(
      'dart',
      [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ],
      workingDirectory: 'shell',
      mode: ProcessStartMode.inheritStdio,
    ))
        .exitCode;

    if (exitCode != 0) {
      exit(exitCode);
    }

    exitCode = await (await Process.start(
      'flutter',
      [
        'build',
        'linux',
        '--${target.name}',
      ],
      workingDirectory: 'shell',
      mode: ProcessStartMode.inheritStdio,
    ))
        .exitCode;
    if (exitCode != 0) {
      exit(exitCode);
    }
    logger.success('\nBuild completed\n');
  }
}
