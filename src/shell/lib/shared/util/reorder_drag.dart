import 'package:flutter/foundation.dart';

/// Whether a panel item (a workspace button or a tileable tab) is being
/// dragged to reorder it.
///
/// The monitor-level cursor listens to this to show the grabbing hand while
/// the dragged feedback follows the pointer, wherever it travels in the view.
class ReorderDragController {
  ReorderDragController._();

  static final instance = ReorderDragController._();

  /// True while at least one panel item is being dragged.
  final isDragging = ValueNotifier<bool>(false);

  int _active = 0;

  void begin() {
    _active++;
    if (_active == 1) isDragging.value = true;
  }

  void end() {
    if (_active == 0) return;
    _active--;
    if (_active == 0) isDragging.value = false;
  }
}
