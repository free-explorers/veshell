import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';

class MonitorRefreshRateValue extends HookConsumerWidget {
  const MonitorRefreshRateValue({
    required this.path,
    super.key,
  });

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = path.split('.');
    final monitorName = paths[paths.length - 2];
    final currentMode =
        ref.watch(monitorByNameProvider(monitorName))?.currentMode;
    if (currentMode == null) {
      return const Text('null');
    }
    return Text(
      '${(currentMode.refreshRate / 1000).round()} Hz',
    );
  }
}
