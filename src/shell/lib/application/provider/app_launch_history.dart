import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/app_launch_history.serializable.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';

part 'app_launch_history.g.dart';

/// The applications launched from the launchers (the tiled launcher and the
/// overview search), with how often and how lately: the launchers offer the
/// most used first.
@Riverpod(keepAlive: true)
@JsonPersist()
class AppLaunchHistoryState extends _$AppLaunchHistoryState {
  String get persistKey => 'app_launch_history';

  @override
  AppLaunchHistory build() {
    // The storage is loaded before the shell's UI; without it (a widget test)
    // the history simply starts empty and is not saved.
    final storage = ref.watch(persistentStorageStateProvider).value;
    if (storage != null) {
      persist(
        storage,
        key: persistKey,
        options: const StorageOptions(
          cacheTime: StorageCacheTime.unsafe_forever,
        ),
      );
    }
    return stateOrNull ?? const AppLaunchHistory(scores: IMapConst({}));
  }

  /// Records that [entry] was launched now.
  void recordLaunch(LocalizedDesktopEntry entry) {
    final id = entry.desktopEntry.id;
    if (id == null) {
      return;
    }
    state = state.withLaunch(id, DateTime.now());
  }
}

/// The desktop file IDs of the launched applications, most used first.
///
/// Ranked when the history changes: between launches the weights all fade at
/// the same rate, so the order holds.
@riverpod
List<String> frequentAppIds(Ref ref) =>
    ref.watch(appLaunchHistoryStateProvider).rankedIds(DateTime.now());
