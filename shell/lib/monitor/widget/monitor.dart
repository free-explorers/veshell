import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/provider/monitor.dart';
import 'package:shell/screen/provider/screen.dart';
import 'package:shell/screen/widget/screen.dart';

/// Widget that represent the Monitor in the widget tree
class MonitorWidget extends HookConsumerWidget {
  /// Const constructor
  const MonitorWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonitorId = ref.watch(currentMonitorProvider);
    final screenList = ref.watch(screenListProvider);
    final screen = ref.watch(
      screenStateProvider(screenList.first),
    );
    return ProviderScope(
      overrides: [
        currentScreenIdProvider.overrideWith((ref) => screen.screenId),
      ],
      child: ScreenWidget(
        screenId: screen.screenId,
      ),
    );
  }
}
