import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/tasks/tasks.provider.dart';

part 'tasks.model.freezed.dart';

@freezed
class TasksState with _$TasksState {
  const factory TasksState({
    required IList<int> tasks,

    /// The list of operations applied to the previous tasks list to obtain current one.
    /// The desktop window stack will use this diff to delay the removal of windows in order to
    /// animate their closing instead of synchronizing with the tasks list immediately.
    required IList<DiffOperation<int>> diff,
  }) = _TasksState;
}
