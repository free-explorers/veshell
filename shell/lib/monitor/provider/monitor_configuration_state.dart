import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/model/monitor_configuration.serializable.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/monitor/provider/monitor_list.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/shared/persistence/persistable_provider.mixin.dart';

part 'monitor_configuration_state.g.dart';

/// Monitor provider
@riverpod
class MonitorConfigurationState extends _$MonitorConfigurationState
    with
        PersistableProvider<MonitorConfiguration,
            AutoDisposeNotifierProviderRef<MonitorConfiguration>> {
  @override
  MonitorConfiguration build(MonitorId monitorId) {
    persistChanges(clearOnDispose: false);

    final monitor = ref.watch(monitorListProvider).firstWhere(
          (element) => element.name == monitorId,
        );

    return getPersisted(MonitorConfiguration.fromJson) ??
        MonitorConfiguration(
          selectedMode: monitor.modes.indexOf(monitor.currentMode!),
          screenConfiguration: ScreenConfiguration(
            screenList: IList(),
            displayMode: ScreenDisplayMode.splitHorizontal,
          ),
        );
  }

  void setScreenList(IList<ScreenId> screenList) {
    state = state.copyWith(
      screenConfiguration:
          state.screenConfiguration.copyWith(screenList: screenList),
    );
  }

  @override
  String getPersistentFolder() => 'Monitor';

  @override
  String getPersistentId() => monitorId;
}
