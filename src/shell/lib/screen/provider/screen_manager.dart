import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/model/screen_manager_state.serializable.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:uuid/uuid.dart';

part 'screen_manager.g.dart';

const _uuidGenerator = Uuid();

/// ScreenList provider
@Riverpod(keepAlive: true)
@JsonPersist()
class ScreenManager extends _$ScreenManager {
  String get persistKey => 'screen_manager';

  @override
  ScreenManagerState build() {
    persist(
      ref.watch(persistentStorageStateProvider).requireValue,
      key: persistKey,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );
    return stateOrNull ?? ScreenManagerState(screenIds: <ScreenId>{}.lock);
  }

  ScreenId createNewScreen() {
    final screenId = _uuidGenerator.v4();
    state = state.copyWith(screenIds: state.screenIds.add(screenId));
    return screenId;
  }

  void removeScreen(ScreenId screenId) {
    ref.read(screenStateProvider(screenId).notifier).delete();
    state = state.copyWith(screenIds: state.screenIds.remove(screenId));
  }

  void removeIfEmpty(ScreenId screenId) {
    final screen = ref.read(screenStateProvider(screenId));
    if (screen.workspaceList.length == 1) {
      final workspace = ref.read(
        workspaceStateProvider(screen.workspaceList.first),
      );
      if (workspace.tileableWindowList.isEmpty) {
        ref.read(screenManagerProvider.notifier).removeScreen(screenId);
      }
    }
  }
}
