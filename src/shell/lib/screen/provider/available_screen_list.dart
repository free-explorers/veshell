import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/monitor/provider/monitor_manager.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_manager.dart';

part 'available_screen_list.g.dart';

@riverpod
ISet<ScreenId> availableScreenList(Ref ref) {
  final screenList = ref.watch(
    screenManagerProvider.select(
      (value) => value.screenIds,
    ),
  );
  final knownMonitorIds = ref.watch(
    monitorManagerProvider.select(
      (value) => value.knownMonitorIds,
    ),
  );

  return screenList.where((screenId) {
    return !knownMonitorIds.any((monitorId) {
      final monitorConfiguration = ref.watch(
        monitorConfigurationStateProvider(monitorId),
      );

      return monitorConfiguration.screenList.any(
        (element) => element.screenId == screenId,
      );
    });
  }).toISet();
}
