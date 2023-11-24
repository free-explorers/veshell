import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../util.dart';

class DevCommand extends Command<int> {
  DevCommand({required this.logger});
  final Logger logger;
  @override
  final name = 'dev';
  @override
  final description = 'Start a build_runner watch and run flutter shell';

  final subProcessList = [];

  @override
  Future<int> run() async {
    await startBuildRunner();
    await startFlutter();
    return ExitCode.success.code;
  }

  Future<bool> startBuildRunner() async {
    final readyFuture = Completer<bool>();
    final buildRunnerProcess = await Process.start(
      'dart',
      ['run', 'build_runner', 'watch'],
      workingDirectory: 'shell',
    );
    await buildRunnerProcess.stdin.close();

    processSet.add(buildRunnerProcess);

    buildRunnerProcess.stdout.transform(utf8.decoder).listen((line) {
      logger.info(line);
      if (line.contains('Succeeded after') == true) {
        readyFuture.complete(true);
      }
    });

    // If the process ends and readyFuture has not been completed, complete it with false
    unawaited(
      buildRunnerProcess.exitCode.then((_) {
        if (!readyFuture.isCompleted) {
          readyFuture.complete(false);
        }
      }),
    );

    return readyFuture.future;
  }

  Future<int> startFlutter() async {
    final flutterProcess = await Process.start(
      'flutter',
      ['run', '-d', 'veshell'],
      workingDirectory: 'shell',
      environment: {
        'XDG_CONFIG_HOME': '${Directory.current.path}/shell/.config',
      },
    );
    await flutterProcess.stdin.close();

    processSet.add(flutterProcess);

    flutterProcess.stdout.transform(utf8.decoder).listen(logger.info);

    return flutterProcess.exitCode;
  }
}
