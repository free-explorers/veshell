import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/monitor/provider/monitor_list.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'monitor_for_screen.g.dart';

@riverpod
Monitor? monitorForScreen(Ref ref, ScreenId screenId) {
  final monitorList = ref.watch(monitorListProvider);
  final monitor = monitorList.firstWhereOrNull((monitor) {
    final monitorConfiguration =
        ref.watch(monitorConfigurationStateProvider(monitor.name));

    return monitorConfiguration.screenList.any(
      (element) => element.screenId == screenId,
    );
  });

  return monitor;
}
