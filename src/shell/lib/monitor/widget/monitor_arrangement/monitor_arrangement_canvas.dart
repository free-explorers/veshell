import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shell/monitor/provider/monitor_arrangement.dart';

/// Canvas that lays every connected monitor out proportionally to its logical
/// size and lets the user drag them relative to each other.
///
/// A single gesture recognizer on the canvas (not on each tile) tracks the
/// drag, so a drag survives the page rebuilding while it is in progress. The
/// monitor under the pointer at drag start is the one moved; a drag that starts
/// on empty space pans the view instead.
///
/// The fit-to-view transform is frozen between drags (it only depends on the
/// monitors' identities, logical sizes and the available space, not on their
/// positions) so that moving a monitor does not rescale the canvas under the
/// pointer. On top of that fit the user can zoom in/out (mouse wheel or
/// trackpad scale) and pan (drag empty space or middle-drag anywhere), which
/// keeps large arrangements navigable.
///
/// A drag accumulates on the raw (unsnapped) position and snapping is applied
/// on top for the displayed position. Snapping from the snapped position
/// instead would cancel every pan delta smaller than the snap threshold and the
/// monitor would never leave its neighbour's edge.
class MonitorArrangementCanvas extends StatefulWidget {
  const MonitorArrangementCanvas({
    required this.placements,
    required this.selectedMonitorId,
    required this.guides,
    required this.onChanged,
    required this.onGuidesChanged,
    required this.onSelected,
    super.key,
  });

  final List<MonitorPlacement> placements;
  final String? selectedMonitorId;
  final SnapResult? guides;
  final void Function(String monitorId, Offset location) onChanged;
  final ValueChanged<SnapResult?> onGuidesChanged;
  final ValueChanged<String> onSelected;

  @override
  State<MonitorArrangementCanvas> createState() =>
      _MonitorArrangementCanvasState();
}

class _MonitorArrangementCanvasState extends State<MonitorArrangementCanvas> {
  late Rect _viewport;
  late double _fitScale;
  Object? _signature;

  /// User zoom on top of the fit-to-view scale. `1` means fit.
  double _zoom = 1;

  /// User pan, in screen pixels, on top of the fit-to-view origin.
  Offset _pan = Offset.zero;

  /// Zoom bounds and the scroll-wheel sensitivity: a larger divisor makes the
  /// wheel gentler. One 20px wheel tick changes the zoom by well under a
  /// percent.
  static const _minZoom = 0.25;
  static const _maxZoom = 8.0;
  static const _scrollZoomFactor = 3000.0;

  /// Monitor currently being dragged and its raw, unsnapped logical position.
  String? _dragMonitorId;
  Offset? _rawLocation;

  /// Whether the in-progress drag pans the view instead of moving a monitor.
  bool _panningView = false;

  /// Pointer id of an in-progress middle-button pan, if any.
  int? _middlePanPointer;

  /// Extra room around the monitors, proportional to their extent: it keeps a
  /// small margin to drag a monitor into without clipping.
  static const _viewportMarginRatio = 0.3;

  /// Rescales around [localPosition] so the logical point under it stays put.
  void _zoomAround(Offset localPosition, double factor) {
    if (_fitScale <= 0) {
      return;
    }
    final newZoom = (_zoom * factor).clamp(_minZoom, _maxZoom).toDouble();
    if (newZoom == _zoom) {
      return;
    }
    final scale = _fitScale * _zoom;
    final logical = Offset(
      (localPosition.dx - _pan.dx) / scale + _viewport.left,
      (localPosition.dy - _pan.dy) / scale + _viewport.top,
    );
    final newScale = _fitScale * newZoom;
    setState(() {
      _zoom = newZoom;
      _pan =
          localPosition -
          Offset(
            (logical.dx - _viewport.left) * newScale,
            (logical.dy - _viewport.top) * newScale,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placements = widget.placements;

    return LayoutBuilder(
      builder: (context, constraints) {
        final signature = Object.hash(
          constraints.maxWidth,
          constraints.maxHeight,
          Object.hashAll(
            placements.map(
              (placement) =>
                  Object.hash(placement.monitorId, placement.logicalSize),
            ),
          ),
        );
        if (_signature != signature) {
          final raw = boundingBoxOf(placements.map((p) => p.rect));
          final margin = math
              .max(raw.longestSide * _viewportMarginRatio, 48)
              .toDouble();
          final box = raw.inflate(margin);
          final width = math.max(box.width, 1);
          final height = math.max(box.height, 1);
          _viewport = box;
          _fitScale = math.min(
            constraints.maxWidth / width,
            constraints.maxHeight / height,
          );
          // A new set of monitors (or a resized canvas) starts fitted.
          _zoom = 1;
          _pan = Offset.zero;
          _signature = signature;
        }

        final viewport = _viewport;
        final scale = _fitScale * _zoom;
        final pan = _pan;

        Offset toScreen(Offset logical) => Offset(
          (logical.dx - viewport.left) * scale + pan.dx,
          (logical.dy - viewport.top) * scale + pan.dy,
        );

        Offset toLogical(Offset local) => Offset(
          (local.dx - pan.dx) / scale + viewport.left,
          (local.dy - pan.dy) / scale + viewport.top,
        );

        MonitorPlacement? placementAt(Offset local) {
          final logical = toLogical(local);
          for (final placement in placements) {
            if (placement.rect.contains(logical)) {
              return placement;
            }
          }
          return null;
        }

        void onPanStart(DragStartDetails details) {
          final placement = placementAt(details.localPosition);
          if (placement == null) {
            _dragMonitorId = null;
            _rawLocation = null;
            _panningView = true;
            return;
          }
          _panningView = false;
          _dragMonitorId = placement.monitorId;
          _rawLocation = placement.location;
          widget.onSelected(placement.monitorId);
        }

        void onPanUpdate(DragUpdateDetails details) {
          if (_panningView) {
            setState(() => _pan += details.delta);
            return;
          }
          final monitorId = _dragMonitorId;
          final rawLocation = _rawLocation;
          if (monitorId == null || rawLocation == null) {
            return;
          }
          final placement = placements.firstWhere(
            (placement) => placement.monitorId == monitorId,
          );
          _rawLocation = rawLocation + details.delta / scale;
          final moved = _rawLocation! & placement.logicalSize;
          final others = placements
              .where((other) => other.monitorId != monitorId)
              .map((other) => other.rect);
          final snap = snapToNeighbours(moved, others);
          widget.onChanged(monitorId, snap.location);
          widget.onGuidesChanged(snap);
        }

        void onPanEnd() {
          final wasPanningView = _panningView;
          _dragMonitorId = null;
          _rawLocation = null;
          _panningView = false;
          if (!wasPanningView) {
            widget.onGuidesChanged(null);
          }
        }

        void onTapUp(TapUpDetails details) {
          final placement = placementAt(details.localPosition);
          if (placement != null) {
            widget.onSelected(placement.monitorId);
          }
        }

        void onPointerSignal(PointerSignalEvent event) {
          if (event is PointerScrollEvent) {
            if (event.scrollDelta.dy == 0) {
              return;
            }
            _zoomAround(
              event.localPosition,
              math.exp(-event.scrollDelta.dy / _scrollZoomFactor),
            );
          } else if (event is PointerScaleEvent) {
            _zoomAround(event.localPosition, event.scale);
          }
        }

        void onPointerDown(PointerDownEvent event) {
          if (event.buttons & kMiddleMouseButton != 0) {
            _middlePanPointer = event.pointer;
          }
        }

        void onPointerMove(PointerMoveEvent event) {
          if (event.pointer == _middlePanPointer) {
            setState(() => _pan += event.delta);
          }
        }

        void onPointerEnd(PointerEvent event) {
          if (event.pointer == _middlePanPointer) {
            _middlePanPointer = null;
          }
        }

        final verticalGuide = widget.guides?.verticalGuide;
        final horizontalGuide = widget.guides?.horizontalGuide;

        return Listener(
          onPointerSignal: onPointerSignal,
          onPointerDown: onPointerDown,
          onPointerMove: onPointerMove,
          onPointerUp: onPointerEnd,
          onPointerCancel: onPointerEnd,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: onPanStart,
            onPanUpdate: onPanUpdate,
            onPanEnd: (_) => onPanEnd(),
            onPanCancel: onPanEnd,
            onTapUp: onTapUp,
            child: Stack(
              children: [
                if (verticalGuide != null)
                  Positioned(
                    left: toScreen(Offset(verticalGuide, 0)).dx,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                if (horizontalGuide != null)
                  Positioned(
                    top: toScreen(Offset(0, horizontalGuide)).dy,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                for (final placement in placements)
                  Positioned(
                    left: toScreen(placement.location).dx,
                    top: toScreen(placement.location).dy,
                    width: placement.logicalSize.width * scale,
                    height: placement.logicalSize.height * scale,
                    child: MonitorArrangementTile(
                      placement: placement,
                      isSelected:
                          placement.monitorId == widget.selectedMonitorId,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Rectangle representing one monitor on the arrangement canvas.
///
/// Purely visual: the canvas handles all gestures so that a drag is not tied to
/// this widget's lifetime.
class MonitorArrangementTile extends StatelessWidget {
  const MonitorArrangementTile({
    required this.placement,
    required this.isSelected,
    super.key,
  });

  final MonitorPlacement placement;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(placement.monitorId, style: theme.textTheme.titleMedium),
                Text(
                  '${placement.logicalSize.width.round()} x '
                  '${placement.logicalSize.height.round()}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
