import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'popup_stack_state.g.dart';

@Riverpod(keepAlive: true)
class PopupStackState extends _$PopupStackState {
  @override
  IList<int> build() {
    return IList();
  }

  void add(int viewId) => state = state.add(viewId);

  void remove(int viewId) => state = state.remove(viewId);
}
