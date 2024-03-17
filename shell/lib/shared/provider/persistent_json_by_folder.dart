import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/persistence/persistence_manager.dart';

part 'persistent_json_by_folder.g.dart';

@Riverpod(keepAlive: true)
class PersistentJsonByFolder extends _$PersistentJsonByFolder {
  @override
  FutureOr<Map<String, Map<String, Map<String, dynamic>>>> build() {
    return PersistenceManager.loadAllModelsJson();
  }
}
