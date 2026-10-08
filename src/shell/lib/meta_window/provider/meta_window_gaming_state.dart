import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'meta_window_gaming_state.g.dart';

enum MetaWindowGamingStatus { running, paused }

@riverpod
class MetaWindowGamingState extends _$MetaWindowGamingState {
  @override
  MetaWindowGamingStatus build(String metaWindowId) {
    // A game starts paused: the tile shows the instructions instead of grabbing
    // input, so the user resumes deliberately.
    return MetaWindowGamingStatus.paused;
  }

  void set(MetaWindowGamingStatus status) {
    state = status;
  }
}
