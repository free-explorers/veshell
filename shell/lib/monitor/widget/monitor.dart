import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/provider/current_monitor.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/screen/provider/current_screen_id.dart';
import 'package:shell/screen/provider/screen_list.dart';
import 'package:shell/screen/widget/screen.dart';

/// Widget that represent the Monitor in the widget tree
class MonitorWidget extends HookConsumerWidget {
  /// Const constructor
  const MonitorWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitorName = ref.watch(currentMonitorProvider);
    final screenConfiguration = ref.watch(
      monitorConfigurationStateProvider(monitorName)
          .select((value) => value.screenConfiguration),
    );

    useEffect(
      () {
        if (screenConfiguration.screenList.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final newScreenId =
                ref.read(screenListProvider.notifier).createNewScreen();
            ref
                .read(monitorConfigurationStateProvider(monitorName).notifier)
                .setScreenList([newScreenId].lock);
          });
        }
        return null;
      },
      [screenConfiguration.screenList],
    );

    return Column(
      children: [
        for (final screenId in screenConfiguration.screenList)
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
