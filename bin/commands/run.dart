import 'dart:async';
import 'dart:convert';
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

    await runner!.run(['build', ...argResults!.arguments]);

    final binaryPath = 'embedder/target/${target.name}/$targetExec';
    final binary = File('${Directory.current.path}/$binaryPath');

    final isTty = !(Platform.environment['DISPLAY'] != null ||
        Platform.environment['WAYLAND_DISPLAY'] != null);

    Process process;
    if (Platform.environment['container'] != null) {
      process = await Process.start(
        'flatpak-spawn',
        ['--host', binary.absolute.path],
        mode: isTty ? ProcessStartMode.normal : ProcessStartMode.inheritStdio,
        workingDirectory: './embedder',
      );
    } else {
      logger.alert('Running ${binary.absolute.path}');
      process = await Process.start(
        binary.path,
        [],
        environment: {
          'RUST_LOG': 'debug',
          'RUST_BACKTRACE': '1',
        },
        mode: isTty ? ProcessStartMode.normal : ProcessStartMode.inheritStdio,
        workingDirectory: './embedder',
      );
    }

    if (isTty) {
      final logFile = File('veshell.log');
      if (logFile.existsSync()) {
        logFile.deleteSync();
      }
      logFile.createSync();
      final logSink = logFile.openWrite();
      logger.alert('storing log at ${logFile.absolute.path}');

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((data) {
        final strippedData =
            data.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');
        logSink.write('$strippedData\n');
      });

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((data) {
        final strippedData =
            data.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');
        logSink.write('$strippedData\n');
      });

      unawaited(
        process.exitCode.then((exitCode) {
          logSink
            ..write('[EXITCODE] $exitCode')
            ..close();
        }),
      );
    }

    processSet.add(process);

    return process.exitCode;
  }
}
