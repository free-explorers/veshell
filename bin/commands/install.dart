import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../util.dart';
import '../veshell.dart';
import 'build.dart';

class InstallCommand extends Command<int> {
  InstallCommand({required this.logger});
  final Logger logger;
  @override
  final name = 'install';
  @override
  final description = 'Build and install Veshell localy';

  // [run] may also return a Future.
  @override
  Future<int> run() async {
    /* final buildCommand = BuildCommand(logger: logger);
    
    await buildCommand.run(); */
    final buildCommandArgs = ['build', ...argResults!.arguments];
    await runner!.runCommand(runner!.parse(buildCommandArgs));
    final target =
        BuildTarget.values.byName(globalResults?['target'] as String);
    await createSession(logger, target: target);

    logger.success(
      'Congratulation Veshell is succesfully installed, you can now logout and select the veshell session in your login manager!\n',
    );
    return ExitCode.success.code;
  }
}

Future<void> createSession(
  Logger logger, {
  BuildTarget target = BuildTarget.debug,
}) async {
  logger.info('Creating session...\n');
  final buildDirectory = Directory('build/${target.name}');

  final desktopFileContent = '''
[Desktop Entry]
Name=Veshell
Exec=${buildDirectory.absolute.path}/$targetExec
Type=Application
X-GDM-SessionRegisters=true
''';

  final desktopFilePath = '${buildDirectory.path}/veshell.desktop';
  logger.info('Creating $desktopFilePath\n');
  final desktopFile = File(desktopFilePath);
  await desktopFile.writeAsString(desktopFileContent);

  logger.info(
    'Installing the session in the system require sudo privileges',
    style: importantStyle,
  );
  if (Platform.environment['container'] != null) {
    logger
      ..err(
        '\nYou are in a container to finish the setup you should call in your host system',
      )
      ..info(
        'sudo mkdir -p /usr/local/share/wayland-sessions && sudo cp ${desktopFile.absolute.path} /usr/local/share/wayland-sessions/',
        style: commandStyle,
      );
  } else {
    await runProcess(
      'sudo',
      ['cp', desktopFilePath, '/usr/share/wayland-sessions/'],
    );
  }

  logger.success('\nSession installation completed\n');
}
