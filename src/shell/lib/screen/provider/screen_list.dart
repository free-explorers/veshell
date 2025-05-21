import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/shared/provider/persistent_json_by_folder.dart';
import 'package:uuid/uuid.dart';

part 'screen_list.g.dart';

/// ScreenList provider
@Riverpod(keepAlive: true)
class ScreenList extends _$ScreenList {
  final _uuidGenerator = const Uuid();

  @override
  ISet<ScreenId> build() {
    final intialSet = ref
            .read(persistentJsonByFolderProvider)
            .requireValue['Screen']
            ?.keys
            .toISet() ??
        <ScreenId>{}.lock;
    return intialSet;
  }

  ScreenId createNewScreen() {
    final screenId = _uuidGenerator.v4();
    state = state.add(screenId);
    return screenId;
  }

  void removeScreen(ScreenId screenId) {
    state = state.remove(screenId);
  }
}
