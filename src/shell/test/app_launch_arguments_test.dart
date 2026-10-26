import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/app_launch.dart';

void main() {
  test('passes cwd and argv as discrete systemd-run arguments', () {
    final arguments = buildTrackedLaunchArguments(
      config: const LaunchConfig(
        argv: ['app', '--flag', '/path with spaces/doc.pdf'],
        workingDirectory: '/home/user/src',
      ),
      unitName: 'veshell-launch-tile-123',
      environment: const {
        'WAYLAND_DISPLAY': 'wayland-1',
        'PWD': '/wrong',
        'OLDPWD': '/old',
      },
    );

    expect(arguments, contains('--working-directory=/home/user/src'));
    expect(arguments, contains('--setenv=WAYLAND_DISPLAY=wayland-1'));
    expect(
      arguments.where((argument) => argument.startsWith('--setenv=PWD')),
      isEmpty,
    );
    expect(arguments.sublist(arguments.length - 3), [
      'app',
      '--flag',
      '/path with spaces/doc.pdf',
    ]);
    expect(arguments, isNot(contains('/bin/sh')));
  });

  test('falls back to the compositor cwd when none is saved', () {
    final arguments = buildTrackedLaunchArguments(
      config: const LaunchConfig(command: 'app'),
      unitName: 'unit',
      environment: const {},
      fallbackWorkingDirectory: '/compositor/cwd',
    );

    expect(arguments, contains('--working-directory=/compositor/cwd'));
    expect(arguments.sublist(arguments.length - 3), ['/bin/sh', '-c', 'app']);
  });

  test('custom exec keeps the shell-form command', () {
    final arguments = buildTrackedLaunchArguments(
      config: const LaunchConfig(command: 'nvim --clean'),
      unitName: 'unit',
      environment: const {},
    );

    expect(arguments.sublist(arguments.length - 3), [
      '/bin/sh',
      '-c',
      'nvim --clean',
    ]);
  });
}
