import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/logs_for_pid.dart';
import 'package:shell/wayland/provider/environment_variables.dart';

part 'app_launch.g.dart';

@Riverpod(keepAlive: true)
class AppLaunch extends _$AppLaunch {
  @override
  void build() {}

  Future<Process> launchApplication(LaunchConfig config) async {
    final environment = ref.read(environmentVariablesProvider);
    final process = await Process.start(
      '/bin/sh',
      ['-c', config.command],
      environment: environment.unlockLazy,
    );
    ref.read(logsForPidProvider(process.pid).notifier).setProcess(process);
    return process;
  }
}
