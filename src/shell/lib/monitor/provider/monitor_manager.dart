import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/model/monitor_manager_state.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';

part 'monitor_manager.g.dart';

/// Registry of every monitor the shell has seen.
///
/// The registry is append-only: ids are never removed on disconnect, so the
/// [MonitorConfigurationState] persisted under a connector name can be restored
/// when the monitor is plugged back in. Whether a known monitor currently owns
/// its screens is decided by `activeMonitorIds`, not by this set.
///
/// This notifier is also the single reconcile point for hotplug: when a monitor
/// reconnects, screens it used that were reassigned to another connected
/// monitor while it was away are dropped from its configuration so the current
/// owner keeps them.
@Riverpod(keepAlive: true)
@JsonPersist()
class MonitorManager extends _$MonitorManager {
  String get persistKey => 'monitor_manager';

  @override
  MonitorManagerState build() {
    persist(
      key: persistKey,
      ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );

    state =
        stateOrNull ?? MonitorManagerState(knownMonitorIds: <MonitorId>{}.lock);

    ref.listen(connectedMonitorListProvider, (previous, next) {
      final previousIds =
          previous?.map((monitor) => monitor.name).toISet() ??
          <MonitorId>{}.lock;
      final connectedIds = next.map((monitor) => monitor.name).toISet();
      for (final monitorId in connectedIds.difference(previousIds)) {
        _dropReassignedScreens(monitorId, connectedIds);
      }
    });

    final connectedMonitorIds = ref
        .watch(connectedMonitorListProvider)
        .map((monitor) => monitor.name)
        .toISet();
    state = state.copyWith(
      knownMonitorIds: state.knownMonitorIds.addAll(connectedMonitorIds),
    );

    return state;
  }

  /// Removes from [monitorId]'s configuration every screen another connected
  /// monitor already owns, so a reconnect never produces two owners for the
  /// same screen.
  void _dropReassignedScreens(
    MonitorId monitorId,
    ISet<MonitorId> connectedIds,
  ) {
    final configuration = ref.read(
      monitorConfigurationStateProvider(monitorId),
    );
    for (final screenConfiguration in configuration.screenList) {
      final screenId = screenConfiguration.screenId;
      final ownedElsewhere = connectedIds.any(
        (otherMonitorId) =>
            otherMonitorId != monitorId &&
            ref
                .read(monitorConfigurationStateProvider(otherMonitorId))
                .screenList
                .any((other) => other.screenId == screenId),
      );
      if (ownedElsewhere) {
        ref
            .read(monitorConfigurationStateProvider(monitorId).notifier)
            .removeScreenConfiguration(screenId);
      }
    }
  }
}
