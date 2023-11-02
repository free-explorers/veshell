import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/mobile/state/task_switcher_state.dart';

class TaskSwitcherScroller extends ConsumerStatefulWidget {
  final ScrollPosition scrollPosition;
  final Widget child;

  const TaskSwitcherScroller({
    Key? key,
    required this.scrollPosition,
    required this.child,
  }) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _TaskSwitcherScrollerState();
}

class _TaskSwitcherScrollerState extends ConsumerState<TaskSwitcherScroller> {
  ScrollDragController? _drag;
  ScrollHoldController? _hold;

  @override
  Widget build(BuildContext context) {
    final inOverview = ref.watch(taskSwitcherStateNotifierProvider.select((v) => v.inOverview));

    Map<Type, GestureRecognizerFactory> gestures = inOverview
        ? {
            HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
              (HorizontalDragGestureRecognizer instance) {
                instance
                  ..onDown = _handleDragDown
                  ..onStart = _handleDragStart
                  ..onUpdate = _handleDragUpdate
                  ..onEnd = _handleDragEnd
                  ..onCancel = _handleDragCancel;
              },
            ),
          }
        : {}; // Disable task switcher gestures when focused on an app.

    return RawGestureDetector(
      behavior: inOverview ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
      gestures: gestures,
      child: widget.child,
    );
  }

  void _handleDragDown(DragDownDetails details) {
    if (!ref.read(taskSwitcherStateNotifierProvider).inOverview) {
      return;
    }
    assert(_drag == null);
    assert(_hold == null);
    _hold = widget.scrollPosition.hold(_disposeHold);
  }

  void _handleDragStart(DragStartDetails details) {
    if (!ref.read(taskSwitcherStateNotifierProvider).inOverview) {
      return;
    }
    // It's possible for _hold to become null between _handleDragDown and
    // _handleDragStart, for example if some user code calls jumpTo or otherwise
    // triggers a new activity to begin.
    assert(_drag == null);
    _drag = widget.scrollPosition.drag(details, _disposeDrag) as ScrollDragController;
    assert(_drag != null);
    assert(_hold == null);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!ref.read(taskSwitcherStateNotifierProvider).inOverview) {
      return;
    }
    double scale = ref.read(taskSwitcherStateNotifierProvider).scale;
    // _drag might be null if the drag activity ended and called _disposeDrag.
    assert(_hold == null || _drag == null);
    _drag?.update(DragUpdateDetails(
      sourceTimeStamp: details.sourceTimeStamp,
      globalPosition: details.globalPosition,
      localPosition: details.localPosition,
      delta: Offset(details.delta.dx / scale, details.delta.dy / scale),
      primaryDelta: details.primaryDelta != null ? details.primaryDelta! / scale : null,
    ));
  }

  void _handleDragEnd(DragEndDetails details) {
    // _drag might be null if the drag activity ended and called _disposeDrag.
    assert(_hold == null || _drag == null);
    double scale = ref.read(taskSwitcherStateNotifierProvider).scale;
    _drag?.end(DragEndDetails(
      velocity: Velocity(pixelsPerSecond: details.velocity.pixelsPerSecond / scale),
      primaryVelocity: details.primaryVelocity != null ? details.primaryVelocity! / scale : null,
    ));
    assert(_drag == null);
  }

  void _handleDragCancel() {
    // _hold might be null if the drag started.
    // _drag might be null if the drag activity ended and called _disposeDrag.
    assert(_hold == null || _drag == null);
    _hold?.cancel();
    _drag?.cancel();
    assert(_hold == null);
    assert(_drag == null);
  }

  void _disposeHold() {
    _hold = null;
  }

  void _disposeDrag() {
    _drag = null;
  }
}
