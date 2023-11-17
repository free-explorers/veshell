import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:veshell/shared/state/task_switcher/task_switcher.model.dart';
import 'package:veshell/shared/tasks/tasks.provider.dart';

part 'task_switcher.provider.g.dart';

@Riverpod(keepAlive: true)
class TaskSwitcher extends _$TaskSwitcher {
  @override
  TaskSwitcherState build() {
    ref.listen(tasksProvider.select((value) => value.tasks.length),
        (_, length) {
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
    final length = ref.read(tasksProvider).tasks.length;
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
    final length = ref.read(tasksProvider).tasks.length;
    if (length == 0) {
      return;
    }
    state = state.copyWith(
      index: (state.index + 1) % ref.read(tasksProvider).tasks.length,
    );
  }

  void previous() {
    final length = ref.read(tasksProvider).tasks.length;
    if (length == 0) {
      return;
    }
    state = state.copyWith(
      index: (state.index - 1) % ref.read(tasksProvider).tasks.length,
    );
  }
}
