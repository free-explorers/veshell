import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    super.key,
  });

  /// Builder function responsible for building an list item with the given data
  final Widget? Function(BuildContext context, T data) itemBuilder;

  /// Builder function responsible for building an list item with the given data
  final Widget Function(BuildContext context, T data)? feedbackBuilder;

  /// The list of data to be displayed
  final List<T> dataList;

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
        localDataList = widget.dataList.toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onExit: (event) {
        if (dropInProgress) {
          localDataList.remove(dropData);
          _clearDropInProgress();
        }
      },
      child: DragTarget(
        onWillAcceptWithDetails: (details) {
          final willAccept = details.data is T;
          if (willAccept) {
            setState(() {
              dropInProgress = true;
              dropData = details.data! as T;
            });
            widget.onDropInProgress?.call(true);
          }
          return willAccept;
        },
        onAccept: (data) {
          _notifyListChanged();
          _clearDropInProgress();
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
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          if (index == localDataList.length - 1)
                            item
                          else
                            LongPressDraggable<T>(
                              onDragCompleted: _notifyListChanged,
                              onDragStarted: () {
                                setState(() {
                                  dropInProgress = true;
                                  dropData = data;
                                  dropIndex = index;
                                });
                                widget.onDropInProgress?.call(true);
                              },
                              onDraggableCanceled: (velocity, offset) {
                                _restoreDatalist();
                              },
                              data: data,
                              feedback: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                constraints: constraints,
                                child: widget.feedbackBuilder
                                        ?.call(context, data) ??
                                    item,
                              ),
                              child: Opacity(
                                opacity: data == dropData ? 0.5 : 1,
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
      child: DragTarget<T>(
        builder: (
          context,
          candidateData,
          rejectedData,
        ) =>
            Container(),
        onWillAccept: (dragData) {
          if (dragData != data &&
              (index == 0 || dragData != localDataList[index - 1])) {
            setState(() {
              localDataList
                ..remove(dragData)
                ..insert(index, dragData!);
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
      child: DragTarget<T>(
        builder: (
          context,
          candidateData,
          rejectedData,
        ) =>
            Container(),
        onWillAccept: (dragData) {
          if (dragData != data &&
              index < localDataList.length - 1 &&
              dragData != localDataList[index + 1]) {
            setState(() {
              localDataList
                ..remove(dragData)
                ..insert(index, dragData!);
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
    if (!listEquals(localDataList, widget.dataList)) {
      widget.onListChanged?.call(localDataList);
    }
  }

  void _restoreDatalist() {
    setState(() {
      localDataList = widget.dataList.toList();
    });
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
