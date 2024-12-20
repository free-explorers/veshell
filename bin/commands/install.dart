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

  BuildTarget get target =>
      BuildTarget.values.byName(globalResults!.option('target')!);
  // [run] may also return a Future.
  @override
  Future<int> run() async {
    await runner!.run(['build', ...argResults!.arguments, '--bundle']);
    await packageBuild(logger, target: target);
    await createSession(logger, target: target);

    logger.success(
      'Congratulation Veshell is succesfully installed, you can now logout and select the veshell session in your login manager!\n',
    );
    return ExitCode.success.code;
  }

  Future<void> packageBuild(
    Logger logger, {
    required BuildTarget target,
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

    var cargoTarget = target;
    if (cargoTarget == BuildTarget.profile) {
      cargoTarget = BuildTarget.release;
    }

    final binaryPath = 'embedder/target/${cargoTarget.name}/$targetExec';
    logger.info('Copy $binaryPath');

    final targetPath = '$buildDirectory/$targetExec';

    // handle (OS Error: Text file busy, errno = 26)
    try {
      await File(binaryPath).copy(targetPath);
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode == 26) {
        final result = Process.runSync('lsof', ['-t', binaryPath]);
        logger.info('kill running process ${result.stdout}');
        final pid = int.tryParse((result.stdout as String).trim());
        if (pid != null) {
          Process.runSync('kill', ['-9', pid.toString()]);
          await File(binaryPath).copy(targetPath); // Retry the copy operation
        }
      } else {
        rethrow; // If it's another error, rethrow it
      }
    }

    final libFlutterEnginePath =
        'embedder/third_party/flutter_engine/${target.name}/libflutter_engine.so';

    logger.info('Copy $libFlutterEnginePath');
    await File(libFlutterEnginePath)
        .copy('$buildDirectory/lib/libflutter_engine.so');

    if (target != BuildTarget.debug) {
      final libAppPath =
          'shell/build/linux/$arch/${target.name}/bundle/lib/libapp.so';
      logger.info('Copy $libAppPath');
      await File(libAppPath).copy('$buildDirectory/lib/libapp.so');
    }

    await runProcess(
      'cp',
      [
        '-r',
        'shell/build/linux/$arch/${target.name}/bundle/data',
        buildDirectory,
      ],
    );

    logger.success('\nPackaging completed\n');
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
    await runProcess(
      'sudo',
      ['chmod', 'a+r', '/usr/share/wayland-sessions/veshell.desktop'],
    );
  }

  logger.success('\nSession installation completed\n');
}
