import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'meta_window_gaming_state.g.dart';

enum MetaWindowGamingStatus {
  running,
  paused,
}

@Riverpod(keepAlive: true)
class MetaWindowGamingState extends _$MetaWindowGamingState {
  @override
  MetaWindowGamingStatus build(String metaWindowId) {
    return MetaWindowGamingStatus.running;
  }

  void set(MetaWindowGamingStatus status) {
    state = status;
  }
}
