import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/shared/persistence/persistable_provider.mixin.dart';

part 'screen_configuration_for_monitor.g.dart';

/// Monitor provider
@riverpod
class ScreenConfigurationForMonitor extends _$ScreenConfigurationForMonitor
    with PersistableProvider<ScreenConfiguration> {
  @override
  ScreenConfiguration build(MonitorId monitorId) {
    persistChanges(clearOnDispose: false);
    return getPersisted(ScreenConfiguration.fromJson) ??
        ScreenConfiguration(
          screenList: IList(),
          displayMode: ScreenDisplayMode.splitHorizontal,
        );
  }

  void setScreenList(IList<ScreenId> screenList) {
    state = state.copyWith(screenList: screenList);
  }

  @override
  String getPersistentFolder() => 'Monitor';

  @override
  String getPersistentId() => monitorId;
}
