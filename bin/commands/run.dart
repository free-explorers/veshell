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

    final binaryPath = 'build/${target.name}/$targetExec';
    final binary = File('${Directory.current.path}/$binaryPath');

    if (!binary.existsSync()) {
      await buildEmbedder(logger, target: target);
      await buildShell(logger, target: target);
    }
    await packageBuild(logger, target: target);

    Process process;
    if (Platform.environment['container'] != null) {
      process = await Process.start(
        'flatpak-spawn',
        ['--host', binary.absolute.path],
        mode: ProcessStartMode.inheritStdio,
      );
    } else {
      logger.alert('Running ${binary.absolute.path}');
      process = await Process.start(
        binary.path,
        [],
        mode: ProcessStartMode.inheritStdio,
      );
    }

    processSet.add(process);

    // Write the PID to a file
    final pidFile = File('process.pid');
    await pidFile.writeAsString(process.pid.toString());

    return process.exitCode;
  }
}
