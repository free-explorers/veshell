import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'screen_manager_state.serializable.freezed.dart';
part 'screen_manager_state.serializable.g.dart';

@freezed
abstract class ScreenManagerState with _$ScreenManagerState {
  const factory ScreenManagerState({
    required ISet<ScreenId> screenIds,
  }) = _ScreenManagerState;
  factory ScreenManagerState.fromJson(Map<String, dynamic> json) =>
      _$ScreenManagerStateFromJson(json);
}
