import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show
        Drag,
        DragEndDetails,
        DragUpdateDetails,
        GestureDisposition,
        GestureMultiDragStartCallback,
        ImmediateMultiDragGestureRecognizer,
        MultiDragGestureRecognizer,
        MultiDragPointerState,
        PointerDownEvent,
        kPrecisePointerHitSlop;
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/multi_view_drag.dart';

/// A [Draggable] that only starts a drag once the pointer has moved by at
/// least [_ThresholdDraggable.threshold] logical pixels.
///
/// Flutter's immediate draggable starts as soon as a mouse moves a single
/// pixel ([kPrecisePointerHitSlop]), which makes it too easy to start a
/// reorder while aiming for a control inside the item (for example its close
/// button).
class _ThresholdDraggable<T extends Object> extends Draggable<T> {
  const _ThresholdDraggable({
    required super.child,
    required super.feedback,
    super.data,
    super.axis,
    super.onDragStarted,
    super.onDraggableCanceled,
    super.onDragCompleted,
    super.onDragEnd,
    super.onDragUpdate,
    super.maxSimultaneousDrags,
    super.hitTestBehavior,
    super.rootOverlay,
    super.allowedButtonsFilter,
    this.onPointerCancel,
  });

  final VoidCallback? onPointerCancel;

  /// Minimum pointer travel, in logical pixels, before a drag starts.
  static const double threshold = 8;

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    return _ThresholdMultiDragGestureRecognizer(
      threshold: threshold,
      allowedButtonsFilter: allowedButtonsFilter,
    )..onStart = (position) {
      final drag = onStart(position);
      return drag == null ? null : _CancelAwareDrag(drag, onPointerCancel);
    };
  }
}

class _CancelAwareDrag implements Drag {
  _CancelAwareDrag(this.drag, this.onCancel);
  final Drag drag;
  final VoidCallback? onCancel;

  @override
  void update(DragUpdateDetails details) => drag.update(details);

  @override
  void end(DragEndDetails details) => drag.end(details);

  @override
  void cancel() {
    onCancel?.call();
    drag.cancel();
  }
}

/// Recognizes a drag once the pointer has travelled a fixed distance, instead
/// of the per-device hit slop that [ImmediateMultiDragGestureRecognizer] uses.
class _ThresholdMultiDragGestureRecognizer extends MultiDragGestureRecognizer {
  _ThresholdMultiDragGestureRecognizer({
    required this.threshold,
    super.debugOwner,
    super.allowedButtonsFilter,
  });

  final double threshold;

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return _ThresholdPointerState(
      event.position,
      event.kind,
      gestureSettings,
      threshold,
    );
  }

  @override
  String get debugDescription => 'threshold multidrag';
}

class _ThresholdPointerState extends MultiDragPointerState {
  _ThresholdPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
    this.threshold,
  );

  final double threshold;

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null, 'A pending delta is expected here');
    if (pendingDelta!.distance > threshold) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

/// A list that allows reordering items among
/// lists sharing the same datatype using drag and drop.
/// The list will notify the parent widget when the list has changed.
/// The parent widget is responsible for updating the list data.
class CrossReorderableList<T extends Object> extends StatefulWidget {
  ///
  const CrossReorderableList({
    required this.itemBuilder,
    required this.dataList,
    this.scrollDirection = Axis.vertical,
    this.onListChanged,
    this.onDropInProgress,
    this.feedbackBuilder,
    this.itemKey,
    super.key,
  });

  /// Builder function responsible for building an list item with the given data
  final Widget? Function(BuildContext context, T data) itemBuilder;

  /// Builder function responsible for building an list item with the given data
  final Widget Function(BuildContext context, T data)? feedbackBuilder;

  /// The list of data to be displayed
  final List<T> dataList;

  /// Stable identity when the data objects are recreated during a drag.
  final Key Function(T data)? itemKey;

  /// The scroll direction of the list
  final Axis scrollDirection;

  /// Callback function that is called when the list has changed
  final void Function(List<T> dataList)? onListChanged;

  /// Callback function that is called when a drop is in progress
  // ignore: avoid_positional_boolean_parameters
  final void Function(bool dropInProgress)? onDropInProgress;
  @override
  State<CrossReorderableList<T>> createState() =>
      _CrossReorderableListState<T>();
}

class _CrossReorderableListState<T extends Object>
    extends State<CrossReorderableList<T>> {
  List<T> localDataList = [];
  bool dropInProgress = false;
  int? dropIndex;
  T? dropData;
  T? _draggedData;
  bool _acceptedHere = false;
  ShellDragSession? _session;

  Key _keyFor(T data) => widget.itemKey?.call(data) ?? ValueKey(data);

  bool _sameItem(T? a, T? b) =>
      a != null && b != null && _keyFor(a) == _keyFor(b);

  int _indexOf(List<T> list, T data) =>
      list.indexWhere((item) => _sameItem(item, data));

  bool _sameOrder(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (!_sameItem(a[index], b[index])) return false;
    }
    return true;
  }

  void _removeItem(T data) {
    localDataList.removeWhere((item) => _sameItem(item, data));
  }

  void _placeRelative(T dragged, T anchor, {bool after = false}) {
    if (_sameItem(dragged, anchor)) return;
    final existingIndex = _indexOf(localDataList, dragged);
    // Keep the latest data object, even if the drag payload predates a rebuild.
    final item = existingIndex < 0 ? dragged : localDataList[existingIndex];
    _removeItem(dragged);
    final anchorIndex = _indexOf(localDataList, anchor);
    localDataList.insert(anchorIndex + (after ? 1 : 0), item);
  }

  void _ensureInserted(T data) {
    if (_indexOf(localDataList, data) >= 0) return;
    // The last item is the pinned launcher/new-workspace slot. Blank-space
    // drops append before it; a genuinely empty list accepts at index zero.
    localDataList.insert(
      localDataList.isEmpty ? 0 : localDataList.length - 1,
      data,
    );
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    localDataList = widget.dataList.toList();
  }

  @override
  void didUpdateWidget(CrossReorderableList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.dataList, oldWidget.dataList)) {
      setState(() {
        if (dropInProgress || _draggedData != null) {
          if (_sameOrder(widget.dataList, oldWidget.dataList)) {
            // A rebuild changed instances, not membership/order. Preserve the
            // pending reorder and foreign preview, refreshing existing data.
            localDataList = localDataList.map((data) {
              final index = _indexOf(widget.dataList, data);
              return index < 0 ? data : widget.dataList[index];
            }).toList();
          } else {
            localDataList = widget.dataList.toList();
          }
        } else {
          localDataList = widget.dataList.toList();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onExit: (event) {
        if (dropInProgress) {
          // Keep the source draggable mounted until release, even outside the
          // list/view. Only foreign hover previews can be removed here.
          if (dropData != null && !_sameItem(dropData, _draggedData)) {
            _removeItem(dropData!);
          }
          _clearDropInProgress();
        }
      },
      child: ShellDragTarget<T>(
        onWillAcceptWithDetails: (details) {
          setState(() {
            dropInProgress = true;
            dropData = details.data;
          });
          widget.onDropInProgress?.call(true);
          return true;
        },
        onAcceptWithDetails: (data) {
          _acceptedHere = _sameItem(data.data, _draggedData);
          _ensureInserted(data.data);
          _notifyListChanged();
          _clearDropInProgress();
        },
        onLeave: (data) {
          if (!_sameItem(data, _draggedData)) {
            _restoreDatalist();
            _clearDropInProgress();
          }
        },
        builder: (context, candidateData, rejectedData) {
          return ListView.custom(
            scrollDirection: widget.scrollDirection,
            childrenDelegate: SliverChildBuilderDelegate(
              (context, index) {
                final data = localDataList[index];
                final item = widget.itemBuilder(context, data);
                if (item != null) {
                  return LayoutBuilder(
                    key: _keyFor(data),
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          if (index == localDataList.length - 1)
                            item
                          else
                            _ThresholdDraggable<T>(
                              // Drags start once the pointer moves past the
                              // threshold, so dragging an item no longer
                              // scrolls the list. That is the trade-off for
                              // making reordering feel like a desktop drag
                              // (long press stays on items for their menus).
                              onDragCompleted: () {
                                if (!_acceptedHere) _removeItem(data);
                                _notifyListChanged();
                                _finishDrag();
                              },
                              onDragStarted: () {
                                _draggedData = data;
                                _acceptedHere = false;
                                _session = ShellDragSession(
                                  context,
                                  data,
                                  ConstrainedBox(
                                    constraints: constraints,
                                    child: widget.feedbackBuilder
                                            ?.call(context, data) ??
                                        item,
                                  ),
                                );
                                setState(() {
                                  dropInProgress = true;
                                  dropData = data;
                                  dropIndex = index;
                                });
                                widget.onDropInProgress?.call(true);
                              },
                              onDraggableCanceled: (velocity, offset) {
                                final accepted = _session?.drop() ?? false;
                                if (accepted) {
                                  _removeItem(data);
                                  _notifyListChanged();
                                } else {
                                  _restoreDatalist();
                                }
                                _finishDrag();
                              },
                              onDragUpdate: (details) =>
                                  _session?.update(details.globalPosition),
                              onPointerCancel: () => _session?.dispose(),
                              maxSimultaneousDrags: 1,
                              data: data,
                              feedback: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white.withAlpha(25),
                                ),
                                constraints: constraints,
                                child: widget.feedbackBuilder
                                        ?.call(context, data) ??
                                    item,
                              ),
                              child: Opacity(
                                opacity: _sameItem(data, dropData) ? 0.5 : 1,
                                child: item,
                              ),
                            ),
                          if (dropInProgress) _buildDragTargets(context, index),
                        ],
                      );
                    },
                  );
                }
                return item;
              },
              childCount: localDataList.length,
              findChildIndexCallback: (key) {
                final index = localDataList.indexWhere(
                  (data) => _keyFor(data) == key,
                );
                return index < 0 ? null : index;
              },
            ),
          );
        },
      ),
    );
  }

  /// Build two different drag targets for each item in the list to determine
  /// if the dragged item should be placed before or after the current item
  Widget _buildDragTargets(BuildContext context, int index) {
    final data = localDataList[index];
    final previousTarget = Expanded(
      child: ShellDragTarget<T>(
        builder: (
          context,
          candidateData,
          rejectedData,
        ) =>
            Container(),
        onWillAcceptWithDetails: (dragData) {
          if (!_sameItem(dragData.data, data) &&
              (index == 0 ||
                  !_sameItem(dragData.data, localDataList[index - 1]))) {
            setState(() {
              _placeRelative(dragData.data, data);
            });
          } else {
            setState(() {
              dropIndex = null;
            });
          }
          return false;
        },
      ),
    );
    final nextTarget = Expanded(
      child: ShellDragTarget<T>(
        builder: (
          context,
          candidateData,
          rejectedData,
        ) =>
            Container(),
        onWillAcceptWithDetails: (dragData) {
          if (!_sameItem(dragData.data, data) &&
              index < localDataList.length - 1 &&
              !_sameItem(dragData.data, localDataList[index + 1])) {
            setState(() {
              _placeRelative(dragData.data, data, after: true);
            });
          } else {
            setState(() {
              dropIndex = null;
            });
          }
          return false;
        },
      ),
    );

    return Positioned.fill(
      child: widget.scrollDirection == Axis.vertical
          ? Column(
              children: [
                previousTarget,
                nextTarget,
              ],
            )
          : Row(
              children: [
                previousTarget,
                nextTarget,
              ],
            ),
    );
  }

  /// Notify the parent widget that the list has changed only if it has changed
  void _notifyListChanged() {
    if (!_sameOrder(localDataList, widget.dataList)) {
      widget.onListChanged?.call(localDataList.toList());
    }
  }

  void _restoreDatalist() {
    setState(() {
      localDataList = widget.dataList.toList();
    });
  }

  void _finishDrag() {
    _session?.dispose();
    _session = null;
    _draggedData = null;
    _acceptedHere = false;
    _clearDropInProgress();
  }

  void _clearDropInProgress() {
    setState(() {
      dropInProgress = false;
      dropData = null;
      dropIndex = null;
    });
    widget.onDropInProgress?.call(false);
  }
}
