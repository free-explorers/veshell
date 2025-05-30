import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/monitor/provider/monitor_manager.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'monitor_for_screen.g.dart';

@riverpod
MonitorId? monitorForScreen(Ref ref, ScreenId screenId) {
  final knownMonitorIds = ref.watch(
    monitorManagerProvider.select(
      (value) => value.knownMonitorIds,
    ),
  );
  final monitor = knownMonitorIds.firstWhereOrNull((monitorId) {
    final monitorConfiguration =
        ref.watch(monitorConfigurationStateProvider(monitorId));

    return monitorConfiguration.screenList.any(
      (element) => element.screenId == screenId,
    );
  });

  return monitor;
}
