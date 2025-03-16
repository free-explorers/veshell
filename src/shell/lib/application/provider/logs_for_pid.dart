import 'dart:io';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logs_for_pid.g.dart';

@Riverpod(keepAlive: true)
class LogsForPid extends _$LogsForPid {
  @override
  List<String> build(int pid) {
    return [];
  }

  void setProcess(Process process) {
    void onEvent(List<int> event) {
      final string = String.fromCharCodes(event);
      state = [...state, string];
    }

    process.stdout.listen(
      onEvent,
    );
    process.stderr.listen(
      onEvent,
    );
  }

  // ignore: avoid_build_context_in_providers
  void openLogsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: state.isNotEmpty
            ? SingleChildScrollView(
                child: Text(state.join('\n')),
              )
            : const Text('No logs yet'),
      ),
    );
  }
}
