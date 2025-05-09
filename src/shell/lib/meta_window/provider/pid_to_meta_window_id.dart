import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pid_to_meta_window_id.g.dart';

@riverpod
class PidToMetaWindowId extends _$PidToMetaWindowId {
  @override
  String? build(int pid) {
    return null;
  }

  void set(String metaWindowId) {
    state = metaWindowId;
  }
}
