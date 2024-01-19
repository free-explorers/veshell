import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:uuid/uuid.dart';

part 'screen_list.g.dart';

/// ScreenList provider
@Riverpod(keepAlive: true)
class ScreenList extends _$ScreenList {
  final _uuidGenerator = const Uuid();

  @override
  ISet<ScreenId> build() {
    return <ScreenId>{}.lock;
  }

  ScreenId createNewScreen() {
    final screenId = _uuidGenerator.v4();

    ref.read(screenStateProvider(screenId).notifier)
      ..initialize(
        Screen(screenId: screenId, workspaceList: IList(), selectedIndex: 0),
      )
      ..createNewWorkspace();

    state = state.add(screenId);
    return screenId;
  }
}
