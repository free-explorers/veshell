import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logs_for_pid.g.dart';

/// Captured output of a launched process, plus whether that process is still
/// running. The liveness flag lets the log view stop drawing the cursor once
/// the process has exited.
class LogsForPidState {
  const LogsForPidState({this.lines = const [], this.isRunning = false});

  final List<String> lines;
  final bool isRunning;

  LogsForPidState copyWith({List<String>? lines, bool? isRunning}) =>
      LogsForPidState(
        lines: lines ?? this.lines,
        isRunning: isRunning ?? this.isRunning,
      );
}

@Riverpod(keepAlive: true)
class LogsForPid extends _$LogsForPid {
  @override
  LogsForPidState build(int pid) {
    return const LogsForPidState();
  }

  void setProcess(Process process, {String? command}) {
    var lines = state.lines;
    if (command != null && command.trim().isNotEmpty) {
      lines = [...lines, '> $command\n'];
    }
    state = LogsForPidState(lines: lines, isRunning: true);

    void onEvent(List<int> event) {
      final string = String.fromCharCodes(event);
      state = state.copyWith(lines: [...state.lines, string]);
    }

    process.stdout.listen(onEvent);
    process.stderr.listen(onEvent);
    unawaited(
      process.exitCode.then((_) {
        state = state.copyWith(isRunning: false);
      }),
    );
  }

  // ignore: avoid_build_context_in_providers
  void openLogsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: state.lines.isNotEmpty
            ? SingleChildScrollView(child: Text(state.lines.join('\n')))
            : const Text('No logs yet'),
      ),
    );
  }
}
