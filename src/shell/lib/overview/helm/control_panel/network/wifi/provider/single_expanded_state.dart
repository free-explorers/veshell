import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'single_expanded_state.g.dart';

@riverpod
class SingleExpanded extends _$SingleExpanded {
  @override
  String? build(String key) {
    return null;
  }

  toggleMe(String key) {
    if (state == key) {
      state = null;
    } else {
      state = key;
    }
  }
}
