import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../util.dart';
import '../veshell.dart';
import 'build.dart';

class RunCommand extends Command<int> {
  RunCommand({required this.logger});
  final Logger logger;
  @override
  final name = 'run';
  @override
  final description = 'run veshell';

  @override
  Future<int> run() async {
    final target =
        BuildTarget.values.byName(globalResults?['target'] as String);

    final binaryPath = 'embedder/target/${target.name}/$targetExec';
    final binary = File('${Directory.current.path}/$binaryPath');

    if (!binary.existsSync()) {
      await runner!.run(['build', ...argResults!.arguments]);
    }

    Process process;
    if (Platform.environment['container'] != null) {
      process = await Process.start(
        'flatpak-spawn',
        ['--host', binary.absolute.path],
        mode: ProcessStartMode.inheritStdio,
        workingDirectory: './embedder',
      );
    } else {
      logger.alert('Running ${binary.absolute.path}');
      process = await Process.start(
        binary.path,
        [],
        mode: ProcessStartMode.inheritStdio,
        workingDirectory: './embedder',
      );
    }

    processSet.add(process);

    return process.exitCode;
  }
}
