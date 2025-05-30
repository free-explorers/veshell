import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';

part 'test.g.dart';

@riverpod
@JsonPersist()
class TestProvider extends _$TestProvider {
  @override
  String build() {
    persist(
      storage: ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );
    print('test build');
    ref.onAddListener(() {
      print('test add listener');
    });
    ref.onRemoveListener(() {
      print('test remove listener');
    });
    ref.onDispose(() {
      print('test dispose');
    });
    ref.onCancel(() {
      print('test cancel');
    });
    ref.onResume(() {
      print('test resume');
    });
    return 'test';
  }
}
