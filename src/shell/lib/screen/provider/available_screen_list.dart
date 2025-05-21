import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/monitor/provider/monitor_list.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_list.dart';

part 'available_screen_list.g.dart';

@riverpod
ISet<ScreenId> availableScreenList(Ref ref) {
  final screenList = ref.watch(screenListProvider);
  final monitorList = ref.watch(monitorListProvider);

  return screenList.where((screenId) {
    return !monitorList.any((monitor) {
      final monitorConfiguration =
          ref.watch(monitorConfigurationStateProvider(monitor.name));

      return monitorConfiguration.screenList.any(
        (element) => element.screenId == screenId,
      );
    });
  }).toISet();
}
