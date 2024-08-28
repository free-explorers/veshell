import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:mason_logger/mason_logger.dart';

import 'commands/build.dart';
import 'commands/clean.dart';
import 'commands/dev.dart';
import 'commands/install.dart';
import 'commands/run.dart';
import 'util.dart';

void main(List<String> arguments) async {
  // The script can either be run from project root or from the shell directory by flutter
  // But the script expect to be run on the project root
  if (Directory.current.path.endsWith('shell')) {
    Directory.current = Directory.current.parent;
  }

  // Listen for termination signal
  ProcessSignal.sigterm.watch().listen((_) {
    for (final process in processSet) {
      process.kill();
    }
    exit(0);
  });

  await _flushThenExit(await VeshellCommandRunner().run(arguments));
}

/// Flushes the stdout and stderr streams, then exits the program with the given
/// status code.
///
/// This returns a Future that will never complete, since the program will have
/// exited already. This is useful to prevent Future chains from proceeding
/// after you've decided to exit.
Future<void> _flushThenExit(int status) {
  return Future.wait<void>([stdout.close(), stderr.close()])
      .then<void>((_) => exit(status));
}

enum BuildTarget { debug, profile, release }

class VeshellCommandRunner extends CompletionCommandRunner<int> {
  VeshellCommandRunner({
    Logger? logger,
  })  : _logger = logger ?? Logger(),
        super('veshell', 'This CLI help install and develop Veshell') {
    argParser
      ..addFlag(
        'verbose',
        help: 'Noisy logging, including all shell commands executed.',
      )
      ..addOption(
        'target',
        abbr: 't',
        help: 'Specify the build target',
        allowed: BuildTarget.values.map((e) => e.name),
        defaultsTo: BuildTarget.debug.name,
      );
    // Add sub commands
    addCommand(BuildCommand(logger: _logger));
    addCommand(InstallCommand(logger: _logger));
    addCommand(DevCommand(logger: _logger));
    addCommand(RunCommand(logger: _logger));
    addCommand(CleanCommand(logger: _logger));
  }

  @override
  void printUsage() => _logger.info(usage);

  final Logger _logger;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final topLevelResults = parse(args);
      if (topLevelResults['verbose'] == true) {
        _logger.level = Level.verbose;
      }
      return await runCommand(topLevelResults) ?? ExitCode.success.code;
    } on FormatException catch (e, stackTrace) {
      // On format errors, show the commands error message, root usage and
      // exit with an error code
      _logger
        ..err(e.message)
        ..err('$stackTrace')
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      // On usage errors, show the commands usage message and
      // exit with an error code
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    // Fast track completion command
    if (topLevelResults.command?.name == 'completion') {
      await super.runCommand(topLevelResults);
      return ExitCode.success.code;
    }

    // Verbose logs
    _logger
      ..detail('Argument information:')
      ..detail('  Top level options:');
    for (final option in topLevelResults.options) {
      if (topLevelResults.wasParsed(option)) {
        _logger.detail('  - $option: ${topLevelResults[option]}');
      }
    }
    if (topLevelResults.command != null) {
      final commandResult = topLevelResults.command!;
      _logger
        ..detail('  Command: ${commandResult.name}')
        ..detail('    Command options:');
      for (final option in commandResult.options) {
        if (commandResult.wasParsed(option)) {
          _logger.detail('    - $option: ${commandResult[option]}');
        }
      }
    }

    return super.runCommand(topLevelResults);
  }
}
