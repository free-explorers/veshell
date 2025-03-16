import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dev_tools_enabled.g.dart';

@riverpod
class DevToolsEnabled extends _$DevToolsEnabled {
  @override
  bool build() {
    return false;
  }

  void toggle() {
    state = !state;
  }
}
