import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/model/monitor_configuration.serializable.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/monitor/provider/monitor_configuration_flex.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';

part 'monitor_configuration_state.g.dart';

/// Authoritative **shell layout** for one monitor: the screens it shows and the
/// split direction between them.
///
/// This state is Flutter-only and keyed by the monitor's connector name; it is
/// never written to `monitor/<connector>.json` and Rust does not consume it.
/// See `docs/specifications/monitor.md`, section "State ownership", for the
/// full ownership model.
@Riverpod(keepAlive: true)
@JsonPersist()
class MonitorConfigurationState extends _$MonitorConfigurationState {
  /// Whether this monitor has an authored configuration, as opposed to the
  /// empty default built for a monitor the shell has never seen.
  ///
  /// It is session state, not persisted: it lets `MonitorWidget` tell "never
  /// configured, give it a screen" from "the user emptied it, leave it empty".
  /// It only stops the widget from refilling a monitor, so an emptied monitor
  /// stays empty while it is connected; reconnecting or restarting the shell
  /// goes through `MonitorManager`, which gives a monitor with no screens a
  /// fresh one. See
  /// `docs/multi-monitor/09-monitor-config-state-correctness.md`.
  bool get isInitialized => _initialized ?? false;
  bool? _initialized;

  @override
  MonitorConfiguration build(MonitorId monitorId) {
    persist(
      ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );
    _initialized ??= stateOrNull != null;
    return stateOrNull ??
        MonitorConfiguration(
          screenList: IList(),
          displayMode: ScreenDisplayMode.splitHorizontal,
        );
  }

  void addNewScreenConfiguration(ScreenId screenId) {
    _initialized = true;
    state = state.copyWith(
      screenList: addScreenToLayout(
        state.screenList,
        screenId,
        primaryForMonitor: monitorId,
      ),
    );
  }

  void removeLastScreenConfiguration() {
    if (state.screenList.isEmpty) {
      return;
    }
    final configuration = state.screenList.last;
    ref
        .read(screenManagerProvider.notifier)
        .removeIfEmpty(configuration.screenId);
    state = state.copyWith(
      screenList: removeLastScreenFromLayout(state.screenList),
    );
  }

  /// Removes the configuration for [screenId] without reflowing the remaining
  /// screens; Flutter normalises the leftover flex values.
  void removeScreenConfiguration(ScreenId screenId) {
    final screenList = state.screenList
        .where((configuration) => configuration.screenId != screenId)
        .toIList();
    if (screenList.length == state.screenList.length) {
      return;
    }
    state = state.copyWith(screenList: screenList);
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
