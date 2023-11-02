import 'dart:async';
import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/common/popup_stack.dart';
import 'package:zenith/ui/common/state/tasks_provider.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';
import 'package:zenith/ui/mobile/app_drawer/handle.dart';
import 'package:zenith/ui/mobile/state/task_state.dart';
import 'package:zenith/ui/mobile/state/task_switcher_state.dart';
import 'package:zenith/ui/mobile/task_switcher/invisible_bottom_bar.dart';
import 'package:zenith/ui/mobile/task_switcher/task_switcher_scroller.dart';

part '../../../generated/ui/mobile/task_switcher/task_switcher.g.dart';

@Riverpod(keepAlive: true)
class TaskList extends _$TaskList {
  @override
  IList<int> build() {
    return IList();
  }

  void init(Iterable<int> values) => state = IList(values);

  void add(int viewId) => state = state.add(viewId);

  void remove(int viewId) => state = state.remove(viewId);

  int? removeAt(int index) {
    final removedItem = Output<int>();
    state = state.removeAt(index, removedItem);
    return removedItem.value;
  }
}

@Riverpod(keepAlive: true)
class ClosingTaskList extends _$ClosingTaskList {
  @override
  IList<int> build() {
    return IList();
  }

  void add(int viewId) => state = state.add(viewId);

  void remove(int viewId) => state = state.remove(viewId);
}

@Riverpod(keepAlive: true)
class TaskSwitcherWidgetStateNotifier extends _$TaskSwitcherWidgetStateNotifier {
  @override
  TaskSwitcherWidgetState build() => TaskSwitcherWidgetState();
}

@Riverpod(keepAlive: true)
class TaskSwitcherPosition extends _$TaskSwitcherPosition {
  @override
  double build() => 0.0;
}

@Riverpod(keepAlive: true)
class _ScrollPositionMinScrollExtent extends _$ScrollPositionMinScrollExtent {
  @override
  double build() => 0.0;
}

@Riverpod(keepAlive: true)
class _ScrollPositionMaxScrollExtent extends _$ScrollPositionMaxScrollExtent {
  @override
  double build() => 1.0;
}

class TaskSwitcher extends ConsumerWidget {
  final double spacing;

  const TaskSwitcher({
    super.key,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        taskSwitcherConstraints = constraints;
        Future.microtask(() {
          ref.read(taskSwitcherStateNotifierProvider.notifier).constraintsHaveChanged();
        });
        return _TaskSwitcherWidget(
          storageContext: context,
          spacing: spacing,
        );
      },
    );
  }
}

class _TaskSwitcherWidget extends ConsumerStatefulWidget {
  final BuildContext storageContext;
  final double spacing;

  const _TaskSwitcherWidget({
    Key? key,
    required this.storageContext,
    required this.spacing,
  }) : super(key: key);

  @override
  ConsumerState<_TaskSwitcherWidget> createState() => TaskSwitcherWidgetState();
}

class TaskSwitcherWidgetState extends ConsumerState<_TaskSwitcherWidget>
    with TickerProviderStateMixin
    implements ScrollContext {

  late final ScrollPosition scrollPosition;

  double get position => scrollPosition.pixels;

  AnimationController? _scaleAnimationController;

  AnimationController? _taskPositionAnimationController;

  @override
  void initState() {
    super.initState();

    // Put the state of this widget in a provider so that the invisible bottom bar can call its methods.
    Future.microtask(() => ref.read(taskSwitcherWidgetStateNotifierProvider.notifier).state = this);

    IList<int> mappedWindows = ref.read(tasksProvider).tasks;

    double lastPosition = ref.read(taskSwitcherPositionProvider);
    double minScrollExtent = 0;
    double maxScrollExtent = _computeScrollableExtent(mappedWindows.length);
    double position = clampDouble(lastPosition, minScrollExtent, maxScrollExtent);

    scrollPosition = ScrollPositionWithSingleContext(
      initialPixels: position,
      physics: const BouncingScrollPhysics(),
      context: this,
      debugLabel: "TaskSwitcherWidget.scrollPosition",
    )
      ..applyViewportDimension(0)
      ..applyContentDimensions(minScrollExtent, maxScrollExtent)
      ..addListener(() {
        ref.read(taskSwitcherPositionProvider.notifier).state = scrollPosition.pixels;
      });

    Future.microtask(() {
      ref.read(taskSwitcherPositionProvider.notifier).state = position;
      _initializeWithTasks(mappedWindows);
    });

    // Avoid executing _spawnTask and _stopTask concurrently because it causes visual glitches.
    // Make sure the async tasks are executed one after the other.
    Future<void> chain = Future.value(null);

    ref.listenManual(windowMappedStreamProvider, (_, AsyncValue<int> next) {
      next.whenData((int viewId) {
        chain = chain.then((_) => _spawnTask(viewId));
      });
    });

    ref.listenManual(windowUnmappedStreamProvider, (_, AsyncValue<int> next) {
      next.whenData((int viewId) {
        chain = chain.then((_) => _closeTask(viewId));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _constraintsChanged(constraints);

        return Stack(
          children: [
            Positioned.fill(
              child: TaskSwitcherScroller(
                scrollPosition: scrollPosition,
                child: Stack(
                  children: [
                    const Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: AppDrawerHandle(),
                    ),
                    Consumer(
                      builder: (_, WidgetRef ref, __) {
                        final tasks = ref.watch(taskListProvider);
                        final closingTasks = ref.watch(closingTaskListProvider);
                        return Stack(
                          children: [
                            for (int viewId in closingTasks) ref.watch(taskWidgetProvider(viewId)),
                            for (int viewId in tasks) ref.watch(taskWidgetProvider(viewId)),
                            const PopupStack(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: InvisibleBottomBar(),
            )
          ],
        );
      },
    );
  }

  void _initializeWithTasks(Iterable<int> viewIds) {
    ref.read(taskListProvider.notifier).init(viewIds);
    _updateContentDimensions();
    _repositionTasks();
  }

  Future<void> _spawnTask(int viewId) {
    final taskIndex = ref.read(taskListProvider).length;

    ref.read(taskListProvider.notifier).add(viewId);
    ref.read(taskPositionProvider(viewId).notifier).state = taskIndexToPosition(taskIndex);

    _updateContentDimensions();

    return switchToTaskByIndex(taskIndex, zoomOut: true);
  }

  Future<void> _closeTask(int viewId) async {
    bool inOverview = ref.read(taskSwitcherStateNotifierProvider).inOverview;
    if (inOverview) {
      return _closeTaskInOverview(viewId);
    } else {
      return _closeTaskNotInOverview(viewId);
    }
  }

  void _constraintsChanged(BoxConstraints constraints) {
    ref
        .read(platformApiProvider.notifier)
        .maximizedWindowSize(constraints.maxWidth.toInt(), constraints.maxHeight.toInt());

    // addPostFrameCallback needed because riverpod triggers setState which cannot be called during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Determine the new scroll position. For example, if it was at 20% of the old scrollable area,
      // it should also be at 20% of the new scrollable area.
      double percent;
      if (scrollPosition.minScrollExtent != scrollPosition.maxScrollExtent) {
        percent = (position - scrollPosition.minScrollExtent) /
            (scrollPosition.maxScrollExtent - scrollPosition.minScrollExtent);
      } else {
        percent = 0.0;
      }

      scrollPosition.applyViewportDimension(constraints.maxWidth);
      _updateContentDimensions();
      _repositionTasks();

      double newPosition = lerpDouble(scrollPosition.minScrollExtent, scrollPosition.maxScrollExtent, percent)!;
      scrollPosition.jumpTo(newPosition);
    });
  }

  /// Readjust the scrollable area.
  void _updateContentDimensions({double? minScrollExtent}) {
    int taskCount = ref.read(taskListProvider).length;
    minScrollExtent = minScrollExtent ?? (scrollPosition.hasContentDimensions ? scrollPosition.minScrollExtent : 0);
    scrollPosition.applyContentDimensions(
      minScrollExtent,
      minScrollExtent + _computeScrollableExtent(taskCount),
    );

    ref.read(_scrollPositionMinScrollExtentProvider.notifier).state = scrollPosition.minScrollExtent;
    ref.read(_scrollPositionMaxScrollExtentProvider.notifier).state = scrollPosition.maxScrollExtent;
  }

  double _computeScrollableExtent(int taskCount) {
    return taskCount <= 1 ? 0 : (taskCount - 1) * _interTaskOffset;
  }

  /// Resets the position of all tasks where they all should be after the animations are finished.
  void _repositionTasks() {
    final IList<int> tasks = ref.read(taskListProvider);
    for (int i = 0; i < tasks.length; i++) {
      ref.read(taskPositionProvider(tasks[i]).notifier).state = taskIndexToPosition(i);
    }
  }

  double taskIndexToPosition(int taskIndex) => scrollPosition.minScrollExtent + taskIndex * _interTaskOffset;

  int taskPositionToIndex(double position) {
    int taskListLength = ref.read(taskListProvider).length;
    if (taskListLength == 0) {
      return 0;
    }
    // 0 is the center of the first task.
    double offset = (position - scrollPosition.minScrollExtent) + _interTaskOffset / 2;
    int index = offset ~/ _interTaskOffset;
    return index.clamp(0, taskListLength - 1);
  }

  double get _interTaskOffset => taskSwitcherConstraints.maxWidth + widget.spacing;

  void _closeTaskInOverview(int viewId) async {
    ref.read(taskStateNotifierProvider(viewId).notifier).startDismissAnimation();

    final tasks = ref.read(taskListProvider);
    int closingTaskIndex = tasks.indexOf(viewId);

    // Dispose the controller instead of just stopping it because we want to clear the listeners.
    _taskPositionAnimationController?.dispose();
    _taskPositionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final controller = _taskPositionAnimationController!;

    int taskIndexUnder = taskPositionToIndex(position);

    // When a task is closed, all tasks to the left or to the right have to move in order to fill the gap.
    bool animateRightSide = false;
    if (taskIndexUnder == closingTaskIndex) {
      if (closingTaskIndex == tasks.length - 1) {
        animateRightSide = false;
      } else {
        animateRightSide = true;
      }
    } else if (closingTaskIndex > taskIndexUnder) {
      animateRightSide = true;
    } else if (closingTaskIndex < taskIndexUnder) {
      animateRightSide = false;
    }

    _putTaskBehind(viewId);

    if (animateRightSide) {
      for (int i = closingTaskIndex + 1; i < tasks.length; i++) {
        Animation<double> animation = Tween(
          begin: ref.read(taskPositionProvider(tasks[i])),
          end: taskIndexToPosition(i - 1),
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutCubic,
        ));

        controller.addListener(() {
          ref.read(taskPositionProvider(tasks[i]).notifier).state = animation.value;
        });
      }
      _updateContentDimensions();
    } else {
      for (int i = 0; i < closingTaskIndex; i++) {
        Animation<double> animation = Tween(
          begin: ref.read(taskPositionProvider(tasks[i])),
          end: taskIndexToPosition(i + 1),
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutCubic,
        ));

        controller.addListener(() {
          ref.read(taskPositionProvider(tasks[i]).notifier).state = animation.value;
        });
      }
      _updateContentDimensions(minScrollExtent: scrollPosition.minScrollExtent + _interTaskOffset);
    }

    await controller.forward(from: 0).orCancel.catchError((ignore) => null);
    _destroyTask(viewId);
  }

  void _closeTaskNotInOverview(int viewId) async {
    final tasks = ref.read(taskListProvider);
    final notifier = ref.read(taskSwitcherStateNotifierProvider.notifier);

    int closingTask = tasks.indexOf(viewId);
    int? focusingTask = taskToFocusAfterClosing(closingTask);

    if (focusingTask == null) {
      // No task left, nothing to animate.
      _destroyTask(viewId);
      _repositionTasks();
      _updateContentDimensions();
      return;
    }

    var currentTask = taskPositionToIndex(position);

    bool zoomOut;
    if (currentTask == closingTask) {
      zoomOut = true;
    } else {
      focusingTask = currentTask;
      zoomOut = false;
    }

    // Don't let the user interact with the task switcher while the animation is ongoing.
    notifier.disableUserControl = true;
    try {
      await switchToTaskByIndex(focusingTask, zoomOut: zoomOut);
    } finally {
      notifier.disableUserControl = false;
    }

    _destroyTask(viewId);

    final minScrollExtent =
        focusingTask > closingTask ? scrollPosition.minScrollExtent + _interTaskOffset : scrollPosition.minScrollExtent;
    _updateContentDimensions(minScrollExtent: minScrollExtent);

    // Just to ensure proper positioning in case the animations glitch out.
    _repositionTasks();
  }

  void _destroyTask(int viewId) {
    ref.read(taskListProvider.notifier).remove(viewId);
    ref.read(closingTaskListProvider.notifier).remove(viewId);

    ref.read(taskStateNotifierProvider(viewId).notifier).dispose();
  }

  int? taskToFocusAfterClosing(int closingTaskIndex) {
    if (ref.read(taskListProvider).length <= 1) {
      return null;
    } else if (closingTaskIndex == 0) {
      return 1;
    } else {
      return closingTaskIndex - 1;
    }
  }

  /// Puts the task on another layer behind all other tasks. All tasks soon to be destroyed are put
  /// on this layer while they are animating.
  void _putTaskBehind(int viewId) {
    ref.read(taskListProvider.notifier).remove(viewId);
    ref.read(closingTaskListProvider.notifier).add(viewId);
  }

  void stopScaleAnimation() {
    _scaleAnimationController?.stop();
    _scaleAnimationController?.dispose();
    _scaleAnimationController = null;
  }

  Future<void> switchToTask(int viewId) async {
    final notifier = ref.read(taskSwitcherStateNotifierProvider.notifier);
    notifier.areAnimationsPlaying = true;
    try {
      await switchToTaskByIndex(ref.read(taskListProvider).indexOf(viewId));
      _moveCurrentTaskToTheEnd();
      _repositionTasks();
      _jumpToLastTask();
    } finally {
      notifier.areAnimationsPlaying = false;
    }
  }

  Future<void> switchToTaskByIndex(int index, {bool zoomOut = false}) async {
    final viewId = ref.read(taskListProvider)[index];

    ref.read(taskSwitcherStateNotifierProvider.notifier).inOverview = false;
    ref.read(xdgToplevelStatesProvider(viewId)).focusNode.requestFocus();

    stopScaleAnimation();
    _scaleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final positionAnimationFuture = scrollPosition.animateTo(
      taskIndexToPosition(index),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );

    final scale = ref.read(taskSwitcherStateNotifierProvider).scale;

    Animatable<double> scaleAnimatable;
    if (zoomOut) {
      scaleAnimatable = TweenSequence([
        TweenSequenceItem(
          weight: 30,
          tween: Tween(begin: scale, end: 0.8),
        ),
        TweenSequenceItem(
          weight: 70,
          tween: Tween(begin: 0.8, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        ),
      ]);
    } else {
      scaleAnimatable = Tween(
        begin: scale,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
    }

    final notifier = ref.read(taskSwitcherStateNotifierProvider.notifier);

    final scaleAnimation = _scaleAnimationController!.drive(scaleAnimatable);
    scaleAnimation.addListener(() => notifier.scale = scaleAnimation.value);

    final scaleAnimationFuture = _scaleAnimationController!.forward().orCancel.catchError((ignore) => null);

    notifier.areAnimationsPlaying = true;
    await Future.wait([positionAnimationFuture, scaleAnimationFuture]);
    notifier.areAnimationsPlaying = false;
  }

  void _moveCurrentTaskToTheEnd() {
    if (ref.read(taskListProvider).isNotEmpty) {
      int currentTaskIndex = taskPositionToIndex(position);
      final notifier = ref.read(taskListProvider.notifier);
      var task = notifier.removeAt(currentTaskIndex)!;
      notifier.add(task);
    }
  }

  void _jumpToLastTask() {
    final tasks = ref.read(taskListProvider);
    scrollPosition.jumpTo(tasks.isNotEmpty ? taskIndexToPosition(tasks.length - 1) : 0);
  }

  Future<void> showOverview() async {
    final notifier = ref.read(taskSwitcherStateNotifierProvider.notifier);
    notifier.inOverview = true;

    stopScaleAnimation();
    _scaleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final positionAnimationFuture = scrollPosition.animateTo(
      taskIndexToPosition(taskPositionToIndex(position)),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );

    final scaleAnimation = _scaleAnimationController!.drive(
      Tween(
        begin: ref.read(taskSwitcherStateNotifierProvider).scale,
        end: 0.6,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    scaleAnimation.addListener(() => notifier.scale = scaleAnimation.value);

    final scaleAnimationFuture = _scaleAnimationController!.forward().orCancel.catchError((ignore) => null);

    notifier.areAnimationsPlaying = true;
    await Future.wait([positionAnimationFuture, scaleAnimationFuture]);
    notifier.areAnimationsPlaying = false;
  }

  @override
  void dispose() {
    scrollPosition.dispose();
    _scaleAnimationController?.dispose();
    super.dispose();
  }

  //
  // ScrollContext overrides
  //

  @override
  AxisDirection get axisDirection => AxisDirection.right;

  @override
  BuildContext? get notificationContext => context;

  @override
  void saveOffset(double offset) {}

  @override
  void setCanDrag(bool value) {}

  @override
  void setIgnorePointer(bool value) {}

  @override
  void setSemanticsActions(Set<SemanticsAction> actions) {}

  @override
  BuildContext get storageContext => widget.storageContext;

  @override
  TickerProvider get vsync => this;

  @override
  double get devicePixelRatio {
    return MediaQuery.maybeDevicePixelRatioOf(storageContext) ?? View.of(storageContext).devicePixelRatio;
  }
}
