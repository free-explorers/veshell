import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/provider/current_monitor.dart';
import 'package:shell/monitor/provider/monitor_list.dart';
import 'package:shell/monitor/widget/monitor.dart';

/// Widget that represent the Display in the widget tree
class DisplayWidget extends HookConsumerWidget {
  /// Const constructor
  const DisplayWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitorList = ref
        .watch(monitorListProvider)
        // Ignore monitors that are connected but not yet configured
        // with a resolution.
        .where((element) => element.currentMode != null);

    return Stack(
      children: [
        for (final monitor in monitorList)
          Positioned.fromRect(
            rect: monitor.location & monitor.currentMode!.size,
            child: ProviderScope(
              overrides: [
                currentMonitorProvider.overrideWith((ref) => monitor.name),
              ],
              child: MonitorWidget(
                key: Key(monitor.name),
              ),
            ),
          ),
      ],
    );
  }
}
