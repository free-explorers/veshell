import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/provider/current_monitor.dart';
import 'package:shell/screen/provider/current_screen_id.dart';
import 'package:shell/screen/provider/screen_list.dart';
import 'package:shell/screen/widget/screen.dart';

/// Widget that represent the Monitor in the widget tree
class MonitorWidget extends HookConsumerWidget {
  /// Const constructor
  const MonitorWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonitorId = ref.watch(currentMonitorProvider);
    final screenList = ref.watch(screenListProvider);
    return Column(
      children: [
        for (final screenId in screenList)
          Flexible(
            child: ProviderScope(
              overrides: [
                currentScreenIdProvider.overrideWith((ref) => screenId),
              ],
              child: const ScreenWidget(),
            ),
          ),
      ],
    );
  }
}
