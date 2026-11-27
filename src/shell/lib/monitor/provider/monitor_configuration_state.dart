import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/model/monitor_configuration.serializable.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/monitor/provider/active_monitor_ids.dart';
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
  /// fresh one.
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
      screenList: _withSavedFlex(
        addScreenToLayout(
          state.screenList,
          screenId,
          primaryForMonitor: monitorId,
        ),
      ),
    );
  }

  /// Adds a screen to this monitor: the first screen no monitor shows, or a
  /// new one when every screen is shown.
  void addScreen() {
    // Not `availableScreenListProvider`: it watches this very provider, so
    // reading it from here is a dependency cycle.
    final shownScreenIds = {
      for (final configuration in state.screenList) configuration.screenId,
      for (final otherMonitorId in ref.read(activeMonitorIdsProvider))
        if (otherMonitorId != monitorId)
          for (final configuration
              in ref
                  .read(monitorConfigurationStateProvider(otherMonitorId))
                  .screenList)
            configuration.screenId,
    };
    final screenId =
        ref
            .read(screenManagerProvider)
            .screenIds
            .firstWhereOrNull(
              (screenId) => !shownScreenIds.contains(screenId),
            ) ??
        ref.read(screenManagerProvider.notifier).createNewScreen();
    addNewScreenConfiguration(screenId);
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
      screenList: _withSavedFlex(removeLastScreenFromLayout(state.screenList)),
    );
  }

  /// [screenList] with the split last saved for its screen count, when there
  /// is one.
  IList<ScreenConfiguration> _withSavedFlex(
    IList<ScreenConfiguration> screenList,
  ) {
    final savedFlex = state.flexForScreenCount['${screenList.length}'];
    if (savedFlex == null || savedFlex.length != screenList.length) {
      return screenList;
    }
    return [
      for (var i = 0; i < screenList.length; i++)
        screenList[i].copyWith(flex: savedFlex[i]),
    ].lock;
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

  /// Shows [newScreenId] where this monitor shows [screenId].
  ///
  /// A screen is laid out on one monitor at a time: when another monitor
  /// shows [newScreenId], that monitor takes [screenId] in exchange, so the
  /// two screens trade monitors instead of [newScreenId] appearing on both.
  void showScreenInPlaceOf(ScreenId screenId, ScreenId newScreenId) {
    if (screenId == newScreenId) {
      return;
    }
    bool shows(MonitorConfiguration configuration) => configuration.screenList
        .any((configuration) => configuration.screenId == newScreenId);
    if (shows(state)) {
      swapScreenIds(screenId, newScreenId);
      return;
    }
    // Not `monitorForScreenProvider`: it watches this very provider, so
    // reading it from here is a dependency cycle.
    final ownerOfNewScreen = ref
        .read(activeMonitorIdsProvider)
        .where((otherMonitorId) => otherMonitorId != monitorId)
        .firstWhereOrNull(
          (otherMonitorId) => shows(
            ref.read(monitorConfigurationStateProvider(otherMonitorId)),
          ),
        );
    if (ownerOfNewScreen != null) {
      ref
          .read(monitorConfigurationStateProvider(ownerOfNewScreen).notifier)
          .replaceScreenIdByScreenId(newScreenId, screenId);
    }
    replaceScreenIdByScreenId(screenId, newScreenId);
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
    // Saved so the monitor gets this split back the next time it shows this
    // many screens.
    state = state.copyWith(
      flexForScreenCount: state.flexForScreenCount.add(
        '${state.screenList.length}',
        state.screenList.map((configuration) => configuration.flex).toIList(),
      ),
    );
  }

  void setDisplayMode(ScreenDisplayMode displayMode) {
    state = state.copyWith(displayMode: displayMode);
  }
}
