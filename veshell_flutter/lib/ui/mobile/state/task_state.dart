import 'package:flutter/cupertino.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/mobile/task_switcher/task.dart';
import 'package:zenith/ui/mobile/task_switcher/task_switcher.dart';

part '../../../generated/ui/mobile/state/task_state.freezed.dart';

part '../../../generated/ui/mobile/state/task_state.g.dart';

@Riverpod(keepAlive: true)
class TaskStateNotifier extends _$TaskStateNotifier {
  @override
  TaskState build(int viewId) {
    return const TaskState(
      dismissState: TaskDismissState.notDismissed,
      startDismissAnimation: Object(),
      cancelDismissAnimation: Object(),
    );
  }

  set dismissState(TaskDismissState value) => state = state.copyWith(dismissState: value);

  void startDismissAnimation() => state = state.copyWith(startDismissAnimation: Object());

  void cancelDismissAnimation() => state = state.copyWith(cancelDismissAnimation: Object());

  @override
  TaskState get state => super.state;

  void dispose() {
    ref.invalidate(taskPositionProvider(viewId));
    ref.invalidate(taskVerticalPositionProvider(viewId));
    ref.invalidate(taskWidgetProvider(viewId));
    ref.invalidate(taskStateNotifierProvider(viewId));
  }
}

@Riverpod(keepAlive: true)
class TaskPosition extends _$TaskPosition {
  @override
  double build(int viewId) => 0.0;
}

@Riverpod(keepAlive: true)
class TaskVerticalPosition extends _$TaskVerticalPosition {
  @override
  double build(int viewId) => 0.0;

  void update(double Function(double) callback) {
    super.state = callback(state);
  }
}

@Riverpod(keepAlive: true)
Task taskWidget(TaskWidgetRef ref, int viewId) {
  return Task(
    key: GlobalKey(),
    viewId: viewId,
    onTap: () => ref.read(taskSwitcherWidgetStateNotifierProvider).switchToTask(viewId),
  );
}

@freezed
class TaskState with _$TaskState {
  const factory TaskState({
    required TaskDismissState dismissState,
    required Object startDismissAnimation,
    required Object cancelDismissAnimation,
  }) = _TaskState;
}

enum TaskDismissState {
  notDismissed,
  dismissing,
  dismissed,
}
