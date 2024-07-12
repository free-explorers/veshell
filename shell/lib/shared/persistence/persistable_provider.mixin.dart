import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/persistence/persistable_model.mixin.dart';
import 'package:shell/shared/persistence/persistence_manager.dart';
import 'package:shell/shared/provider/persistent_json_by_folder.dart';

mixin PersistableProvider<T extends PersistableModel, RefT extends Ref<T>> {
  RefT get ref;

  String getPersistentFolder();
  String getPersistentId();

  bool _isInitialized = false;

  T? getPersisted(T Function(Map<String, dynamic>) fromJsonConstructor) {
    final persistedJson = ref
        .read(persistentJsonByFolderProvider)
        .requireValue[getPersistentFolder()]?[getPersistentId()];

    if (persistedJson == null) return null;

    try {
      return fromJsonConstructor(persistedJson);
    } catch (e) {
      print(
        'Error parsing persisted json for ${getPersistentFolder()}-${getPersistentId()}: $e',
      );
      PersistenceManager.deleteModelJson(
        getPersistentFolder(),
        getPersistentId(),
      );
      return null;
    }
  }

  void persistChanges({bool clearOnDispose = true}) {
    if (_isInitialized) return;
    _isInitialized = true;
    ref.listenSelf((previous, next) {
      if (previous != next) {
        print(
          'Persisting changes for ${getPersistentFolder()}-${getPersistentId()}',
        );
        PersistenceManager.queueStoreModelJson(
          getPersistentFolder(),
          getPersistentId(),
          next.toJson(),
        );
      }
    });
    if (clearOnDispose == false) return;
    ref.onDispose(() {
      print(
        'Deleting persisted model for ${getPersistentFolder()}-${getPersistentId()}',
      );
      PersistenceManager.deleteModelJson(
        getPersistentFolder(),
        getPersistentId(),
      );
    });
  }
}
