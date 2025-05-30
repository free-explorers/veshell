import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/model/monitor_manager_state.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';

part 'monitor_manager.g.dart';

@Riverpod(keepAlive: true)
@JsonPersist()
class MonitorManager extends _$MonitorManager {
  String get persistKey => 'monitor_manager';

  @override
  MonitorManagerState build() {
    persist(
      key: persistKey,
      storage: ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );

    state =
        stateOrNull ?? MonitorManagerState(knownMonitorIds: <MonitorId>{}.lock);

    final connectedMonitorList = ref.watch(connectedMonitorListProvider);

    for (final monitor in connectedMonitorList) {
      state = state.copyWith(
        knownMonitorIds: state.knownMonitorIds.add(monitor.name),
      );
    }

    return state;
  }
}
