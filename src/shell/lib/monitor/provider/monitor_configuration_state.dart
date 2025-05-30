import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/model/monitor_configuration.serializable.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';

part 'monitor_configuration_state.g.dart';

/// Monitor provider
@Riverpod(keepAlive: true)
@JsonPersist()
class MonitorConfigurationState extends _$MonitorConfigurationState {
  @override
  MonitorConfiguration build(MonitorId monitorId) {
    persist(
      storage: ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );
    return stateOrNull ??
        MonitorConfiguration(
          screenList: IList(),
          displayMode: ScreenDisplayMode.splitHorizontal,
        );
  }

  void setScreenList(IList<ScreenId> screenList) {
    //state = state.copyWith(screenList: screenList);
  }

  void addNewScreenConfiguration(ScreenId screenId) {
    final newFlex = 100 ~/ (state.screenList.length + 1);
    state = state.copyWith(
      screenList: state.screenList
          .map(
            (screenConfiguration) => screenConfiguration.copyWith(
              flex:
                  screenConfiguration.flex - newFlex ~/ state.screenList.length,
            ),
          )
          .toIList(),
    );

    // determine the new flex value based on all the other flex values to proportionally split the screen

    state = state.copyWith(
      screenList: [
        ...state.screenList,
        ScreenConfiguration(
          flex: newFlex,
          screenId: screenId,
          primaryForMonitor: state.screenList.isEmpty ? monitorId : null,
        ),
      ].lock,
    );
  }

  void removeLastScreenConfiguration() {
    final configuration = state.screenList.last;
    ref
        .read(screenManagerProvider.notifier)
        .removeIfEmpty(configuration.screenId);
    state = state.copyWith(
      screenList: state.screenList
          .removeLast()
          .map(
            (screenConfiguration) => screenConfiguration.copyWith(
              flex: screenConfiguration.flex +
                  configuration.flex ~/ (state.screenList.length - 1),
            ),
          )
          .toIList(),
    );
  }

  void setScreenIdForScreenConfiguration(
    ScreenConfiguration screenConfiguration,
    ScreenId screenId,
  ) {
    state = state.copyWith(
      screenList: state.screenList
          .map(
            (screenConfiguration) => screenConfiguration == screenConfiguration
                ? screenConfiguration.copyWith(screenId: screenId)
                : screenConfiguration,
          )
          .toIList(),
    );
  }

  void replaceScreenIdByScreenId(ScreenId screenId, ScreenId newScreenId) {
    state = state.copyWith(
      screenList: state.screenList
          .map(
            (screenConfiguration) => screenConfiguration.screenId == screenId
                ? screenConfiguration.copyWith(screenId: newScreenId)
                : screenConfiguration,
          )
          .toIList(),
    );
  }

  void swapScreenIds(ScreenId screenIdA, ScreenId screenIdB) {
    state = state.copyWith(
      screenList: state.screenList
          .map(
            (screenConfiguration) => screenConfiguration.screenId == screenIdA
                ? screenConfiguration.copyWith(screenId: screenIdB)
                : screenConfiguration.screenId == screenIdB
                    ? screenConfiguration.copyWith(screenId: screenIdA)
                    : screenConfiguration,
          )
          .toIList(),
    );
  }

  void updateFlexForConfiguration(
    ScreenConfiguration screenConfiguration,
    int flex,
  ) {
    state = state.copyWith(
      screenList: state.screenList
          .map(
            (aScreenConfiguration) =>
                aScreenConfiguration == screenConfiguration
                    ? aScreenConfiguration.copyWith(flex: flex)
                    : aScreenConfiguration,
          )
          .toIList(),
    );
  }

  void setDisplayMode(ScreenDisplayMode displayMode) {
    state = state.copyWith(displayMode: displayMode);
  }
}
