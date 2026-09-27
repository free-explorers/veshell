import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show immutable;
import 'package:shell/monitor/model/monitor.serializable.dart';

/// Default snapping distance, in logical pixels, when dragging a monitor.
const arrangementSnapThreshold = 12.0;

/// Ignore sub-pixel moves when deciding whether a monitor was moved.
const arrangementMoveEpsilon = 0.5;

/// Desired logical placement of one monitor on the arrangement canvas.
///
/// A monitor's physical mode is divided by its fractional scale to get the
/// logical size the compositor lays out, so the canvas shows the same geometry
/// Rust applies from `monitor/<connector>.json`.
@immutable
class MonitorPlacement {
  const MonitorPlacement({
    required this.monitorId,
    required this.description,
    required this.logicalSize,
    required this.location,
    required this.scale,
  });

  factory MonitorPlacement.fromMonitor({
    required Monitor monitor,
    required double scale,
  }) {
    return MonitorPlacement(
      monitorId: monitor.name,
      description: monitor.description,
      logicalSize: monitorLogicalSize(monitor, scale),
      location: monitor.location,
      scale: scale,
    );
  }

  final MonitorId monitorId;
  final String description;
  final Size logicalSize;
  final Offset location;
  final double scale;

  Rect get rect => location & logicalSize;

  MonitorPlacement copyWith({Offset? location}) => MonitorPlacement(
    monitorId: monitorId,
    description: description,
    logicalSize: logicalSize,
    location: location ?? this.location,
    scale: scale,
  );

  @override
  bool operator ==(Object other) =>
      other is MonitorPlacement &&
      other.monitorId == monitorId &&
      other.description == description &&
      other.logicalSize == logicalSize &&
      other.location == location &&
      other.scale == scale;

  @override
  int get hashCode =>
      Object.hash(monitorId, description, logicalSize, location, scale);
}

/// Logical size (physical pixels divided by the fractional scale) of [monitor].
Size monitorLogicalSize(Monitor monitor, double scale) {
  final mode = monitor.currentMode;
  if (mode == null || scale <= 0) {
    return Size.zero;
  }
  return Size(mode.size.width / scale, mode.size.height / scale);
}

/// The compositor's default arrangement: [placements] laid left-to-right at
/// `y = 0` starting from the origin, keeping each monitor's logical size (and
/// therefore its mode and scale).
///
/// Mirrors Rust's `place_new_output`; `Reset to default` uses it to restore
/// only the locations.
List<MonitorPlacement> autoArrangement(List<MonitorPlacement> placements) {
  var x = 0.0;
  final arranged = <MonitorPlacement>[];
  for (final placement in placements) {
    arranged.add(placement.copyWith(location: Offset(x, 0)));
    x += placement.logicalSize.width;
  }
  return arranged;
}

/// Smallest rectangle containing every rectangle in [rects].
Rect boundingBoxOf(Iterable<Rect> rects) {
  if (rects.isEmpty) {
    return Rect.zero;
  }
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final rect in rects) {
    left = math.min(left, rect.left);
    top = math.min(top, rect.top);
    right = math.max(right, rect.right);
    bottom = math.max(bottom, rect.bottom);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

/// Top-left of the bounding box of [rects], the origin of the arrangement.
///
/// Returns [Offset.zero] for an empty input.
Offset arrangementOrigin(Iterable<Rect> rects) => boundingBoxOf(rects).topLeft;

/// Returns [placements] translated so their bounding-box top-left is `(0, 0)`.
///
/// The arrangement canvas only ever manipulates relative positions in this
/// normalised space; applying translates it back to a `(0, 0)`-based absolute
/// location.
List<MonitorPlacement> toRelativeArrangement(
  List<MonitorPlacement> placements,
) {
  if (placements.isEmpty) {
    return placements;
  }
  final origin = arrangementOrigin(placements.map((p) => p.rect));
  return [
    for (final placement in placements)
      placement.copyWith(location: placement.location - origin),
  ];
}

/// Result of snapping a dragged monitor against its neighbours.
class SnapResult {
  const SnapResult({
    required this.location,
    this.verticalGuide,
    this.horizontalGuide,
  });

  /// Snapped top-left position of the dragged monitor.
  final Offset location;

  /// Logical x of the vertical alignment guide, when a snap occurred.
  final double? verticalGuide;

  /// Logical y of the horizontal alignment guide, when a snap occurred.
  final double? horizontalGuide;
}

/// Snaps [moving] to the closest edge or centre of any rectangle in [others].
///
/// Only a single edge on each axis is snapped, so the dragged monitor keeps its
/// relative offset on the other axis. The returned guides are the logical
/// coordinates to draw, or `null` when no snap occurred.
SnapResult snapToNeighbours(
  Rect moving,
  Iterable<Rect> others, {
  double threshold = arrangementSnapThreshold,
}) {
  final xTargets = <double>[];
  final yTargets = <double>[];
  for (final other in others) {
    xTargets
      ..add(other.left)
      ..add(other.center.dx)
      ..add(other.right);
    yTargets
      ..add(other.top)
      ..add(other.center.dy)
      ..add(other.bottom);
  }

  var bestDx = 0.0;
  var bestDxDistance = threshold;
  double? verticalGuide;
  for (final edge in [moving.left, moving.center.dx, moving.right]) {
    for (final target in xTargets) {
      final distance = (target - edge).abs();
      if (distance <= bestDxDistance) {
        bestDxDistance = distance;
        bestDx = target - edge;
        verticalGuide = target;
      }
    }
  }

  var bestDy = 0.0;
  var bestDyDistance = threshold;
  double? horizontalGuide;
  for (final edge in [moving.top, moving.center.dy, moving.bottom]) {
    for (final target in yTargets) {
      final distance = (target - edge).abs();
      if (distance <= bestDyDistance) {
        bestDyDistance = distance;
        bestDy = target - edge;
        horizontalGuide = target;
      }
    }
  }

  return SnapResult(
    location: Offset(moving.left + bestDx, moving.top + bestDy),
    verticalGuide: verticalGuide,
    horizontalGuide: horizontalGuide,
  );
}

/// Whether any two rectangles in [rects] overlap by more than [tolerance].
///
/// Merely touching edges do not count as an overlap.
bool arrangementsOverlap(
  Iterable<Rect> rects, {
  double tolerance = arrangementMoveEpsilon,
}) {
  final list = rects.toList();
  for (var i = 0; i < list.length; i++) {
    for (var j = i + 1; j < list.length; j++) {
      final a = list[i].deflate(tolerance);
      final b = list[j].deflate(tolerance);
      if (a.overlaps(b)) {
        return true;
      }
    }
  }
  return false;
}

/// Locations in [after] that differ from [before] by more than [tolerance].
Map<MonitorId, Offset> changedLocations(
  Map<MonitorId, Offset> before,
  Map<MonitorId, Offset> after, {
  double tolerance = arrangementMoveEpsilon,
}) {
  final changed = <MonitorId, Offset>{};
  for (final entry in after.entries) {
    final previous = before[entry.key];
    if (previous == null || (previous - entry.value).distance > tolerance) {
      changed[entry.key] = entry.value;
    }
  }
  return changed;
}
