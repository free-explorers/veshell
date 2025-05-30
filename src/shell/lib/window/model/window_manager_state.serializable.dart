import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/window/model/window_id.serializable.dart';

part 'window_manager_state.serializable.freezed.dart';
part 'window_manager_state.serializable.g.dart';

@freezed
abstract class WindowManagerState with _$WindowManagerState {
  const factory WindowManagerState({
    required ISet<WindowId> windows,
  }) = _WindowManagerState;

  factory WindowManagerState.fromJson(Map<String, dynamic> json) =>
      _$WindowManagerStateFromJson(json);
}
