import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/logs_for_pid.dart';

class LogsViewer extends HookConsumerWidget {
  const LogsViewer({required this.pid, super.key});

  final int pid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(logsForPidProvider(pid));
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        itemBuilder: (context, index) => Text(logs[index]),
        itemCount: logs.length,
      ),
    );
  }
}
