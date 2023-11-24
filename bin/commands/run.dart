import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

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
    const target = BuildTarget.debug;

    final binaryPath = 'build/${target.name}/$targetExec';
    final binary = File('${Directory.current.path}/$binaryPath');

    if (!binary.existsSync()) {
      await buildAll(logger);
    }
    if (Platform.environment['container'] != null) {
      await Process.start(
        'flatpak-spawn',
        ['--host', binary.absolute.path],
        mode: ProcessStartMode.inheritStdio,
      );
    }
    await Process.start(
      binary.path,
      [],
      mode: ProcessStartMode.inheritStdio,
    );
    return ExitCode.success.code;
  }
}
