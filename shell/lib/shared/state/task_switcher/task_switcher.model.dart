import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_switcher.model.freezed.dart';

@freezed
class TaskSwitcherState with _$TaskSwitcherState {
  const factory TaskSwitcherState({
    required bool shown,
    required int index,
  }) = _TaskSwitcherState;
}
