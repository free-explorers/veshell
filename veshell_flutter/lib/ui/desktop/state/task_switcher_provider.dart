import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/common/state/tasks_provider.dart';

part '../../../generated/ui/desktop/state/task_switcher_provider.freezed.dart';

part '../../../generated/ui/desktop/state/task_switcher_provider.g.dart';

@Riverpod(keepAlive: true)
class TaskSwitcher extends _$TaskSwitcher {
  @override
  TaskSwitcherState build() {
    ref.listen(tasksProvider.select((value) => value.tasks.length), (_, length) {
      if (length == 0) {
        return;
      }
      state = state.copyWith(index: state.index % length);
    });

    return const TaskSwitcherState(
      shown: false,
      index: 0,
    );
  }

  void show(bool right) {
    int length = ref.read(tasksProvider).tasks.length;
    state = state.copyWith(
      shown: true,
      index: length < 2
          ? 0
          : right
              ? 1
              : length - 1,
    );
  }

  void hide() {
    state = state.copyWith(
      shown: false,
    );
  }

  void next() {
    int length = ref.read(tasksProvider).tasks.length;
    if (length == 0) {
      return;
    }
    state = state.copyWith(
      index: (state.index + 1) % ref.read(tasksProvider).tasks.length,
    );
  }

  void previous() {
    int length = ref.read(tasksProvider).tasks.length;
    if (length == 0) {
      return;
    }
    state = state.copyWith(
      index: (state.index - 1) % ref.read(tasksProvider).tasks.length,
    );
  }
}

@freezed
class TaskSwitcherState with _$TaskSwitcherState {
  const factory TaskSwitcherState({
    required bool shown,
    required int index,
  }) = _TaskSwitcherState;
}
