import 'dart:io';

import 'util.dart';

enum BuildTarget { debug, profile, release }

const targetExec = 'veshell';

Future<void> buildEmbedder({BuildTarget target = BuildTarget.debug}) async {
  print('Building the rust embedder in ${target.name}...\n');
  final exitCode = await runProcess('cargo', ['build', '--color', 'always'],
      workingDirectory: 'embedder',
      environment: {'FLUTTER_ENGINE_BUILD': target.name});
  if (exitCode != 0) {
    exit(exitCode);
  }
  print(successColor('Build completed\n'));
}

Future<void> buildShell({BuildTarget target = BuildTarget.debug}) async {
  print('Building the shell in ${target.name}...\n');
  var exitCode = await runProcess(
      'dart',
      [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ],
      workingDirectory: 'shell',
      environment: {'FORCE_COLOR': 'true'});

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
      environment: {'FORCE_COLOR': 'true'});
  if (exitCode != 0) {
    exit(exitCode);
  }
  print(successColor('Build completed\n'));
}

Future<void> packageBuild({BuildTarget target = BuildTarget.debug}) async {
  print('Packaging build...\n');

  var unameM = (await Process.run('uname', ['-m'])).stdout;

  var arch = '';

  if (unameM.contains('x86_64')) {
    arch = 'x64';
  } else {
    arch = 'arm64';
  }

  final buildDirectory = 'build/${target.name}';
  print('Create $buildDirectory directory');
  await Directory('$buildDirectory/lib/').create(recursive: true);

  final binaryPath = 'embedder/target/${target.name}/$targetExec';
  print('Copy $binaryPath');
  await File(binaryPath).copy('$buildDirectory/$targetExec');

  final libFlutterEnginePath =
      'embedder/third_party/flutter_engine/${target.name}/libflutter_engine.so';

  print('Copy $libFlutterEnginePath');
  await File(libFlutterEnginePath)
      .copy('$buildDirectory/lib/libflutter_engine.so');

  await runProcess('cp',
      ['-r', 'shell/build/linux/$arch/debug/bundle/data', buildDirectory]);

  print(successColor('\nPackaging completed\n'));
}

Future<void> createSession({BuildTarget target = BuildTarget.debug}) async {
  print('Creating session...\n');
  final buildDirectory = Directory('build/${target.name}');

  var desktopFileContent = '''
[Desktop Entry]
Name=Veshell
Exec=${buildDirectory.absolute.path}/$targetExec
Type=Application
X-GDM-SessionRegisters=true
''';

  final desktopFilePath = '${buildDirectory.path}/veshell.desktop';
  print('Creating $desktopFilePath\n');
  var desktopFile = File(desktopFilePath);
  await desktopFile.writeAsString(desktopFileContent);

  print(importantColor(
      'Installing the session in the system require sudo privileges'));
  await runProcess(
      'sudo', ['cp', desktopFilePath, '/usr/share/wayland-sessions/']);

  print(successColor('\nSession installation completed\n'));
}
