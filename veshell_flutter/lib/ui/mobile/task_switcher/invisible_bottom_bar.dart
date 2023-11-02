import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/mobile/state/task_switcher_state.dart';
import 'package:zenith/ui/mobile/task_switcher/task_switcher.dart';

class InvisibleBottomBar extends ConsumerStatefulWidget {
  const InvisibleBottomBar({Key? key}) : super(key: key);

  @override
  ConsumerState<InvisibleBottomBar> createState() => _InvisibleBottomBarState();
}

class _InvisibleBottomBarState extends ConsumerState<InvisibleBottomBar> {
  ScrollDragController? drag;
  late var tm = ref.read(taskSwitcherWidgetStateNotifierProvider);
  int draggingTask = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, WidgetRef ref, Widget? child) {
        final disableUserControl = ref.watch(taskSwitcherStateNotifierProvider.select((v) => v.disableUserControl));
        return AbsorbPointer(
          absorbing: disableUserControl,
          child: child!,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: _onPointerDown,
        onPanUpdate: _onPointerMove,
        onPanEnd: _onPointerUp,
        child: IgnorePointer(
          child: Container(
            height: 20,
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }

  void _onPointerDown(DragStartDetails details) {
    if (ref.read(taskListProvider).isEmpty) {
      return;
    }
    tm.stopScaleAnimation();
    drag = tm.scrollPosition.drag(
      DragStartDetails(
        sourceTimeStamp: details.sourceTimeStamp!,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
        kind: details.kind,
      ),
      _disposeDrag,
    ) as ScrollDragController;
    draggingTask = tm.taskPositionToIndex(tm.position);
  }

  void _onPointerMove(DragUpdateDetails details) {
    if (drag == null) {
      return;
    }
    final notifier = ref.read(taskSwitcherStateNotifierProvider.notifier);

    if (ref.read(taskListProvider).isNotEmpty) {
      double scale = ref.read(taskSwitcherStateNotifierProvider).scale;
      notifier.scale = (scale + details.delta.dy / taskSwitcherConstraints.maxHeight * 2).clamp(0.5, 1);
      scale = ref.read(taskSwitcherStateNotifierProvider).scale;

      drag?.update(DragUpdateDetails(
        sourceTimeStamp: details.sourceTimeStamp!,
        globalPosition: details.globalPosition,
        delta: Offset(details.delta.dx / scale, 0),
        primaryDelta: details.delta.dx / scale,
      ));
    }
  }

  void _onPointerUp(DragEndDetails details) {
    if (drag == null) {
      return;
    }
    drag?.cancel();

    final tasks = ref.read(taskListProvider);
    var vel = details.velocity.pixelsPerSecond;
    var taskOffset = tm.taskIndexToPosition(tm.taskPositionToIndex(tm.position));

    if (vel.dx.abs() > 365 && vel.dx.abs() > vel.dy.abs()) {
      // Flick to the left or right.
      int targetTaskIndex;
      if (vel.dx < 0 && tm.position > taskOffset) {
        // Next task.
        targetTaskIndex = (tm.taskPositionToIndex(tm.position) + 1).clamp(0, tasks.length - 1);
      } else if (vel.dx > 0 && tm.position < taskOffset) {
        // Previous task.
        targetTaskIndex = (tm.taskPositionToIndex(tm.position) - 1).clamp(0, tasks.length - 1);
      } else {
        // Same task.
        targetTaskIndex = tm.taskPositionToIndex(tm.position);
      }
      tm.switchToTaskByIndex(targetTaskIndex);
    } else if (vel.dy < -200) {
      // Flick up.
      tm.showOverview();
    } else if (vel.dy > 200) {
      // Flick down.
      tm.switchToTaskByIndex(tm.taskPositionToIndex(tm.position));
    } else {
      // Lift finger while standing still.
      int taskInFront = tm.taskPositionToIndex(tm.position);
      if (taskInFront != draggingTask || ref.read(taskSwitcherStateNotifierProvider).scale > 0.9) {
        tm.switchToTaskByIndex(taskInFront);
      } else {
        tm.showOverview();
      }
    }
  }

  void _disposeDrag() {
    drag = null;
  }
}
