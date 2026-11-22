import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Paints [child] on the view's physical pixel grid.
///
/// A live Wayland surface is an external texture sampled bilinearly, so it is
/// only sharp when its origin lands on a whole *physical* pixel. Rounding
/// layout to whole logical pixels (see `snapToWholePixel`) is not enough on a
/// fractional output: at 1.25 an odd logical origin is a quarter or a half
/// physical pixel, and every centring, margin and CSD offset above the surface
/// adds its own remainder. This widget absorbs whatever remainder the layout
/// produced, at paint time, by shifting the child by less than one physical
/// pixel.
///
/// It only acts when the path to the view is a pure translation: a scaled
/// surface (an overview thumbnail, a fixed-size dialog fitted down) is
/// resampled anyway and is painted where the layout put it.
class PhysicalPixelSnap extends SingleChildRenderObjectWidget {
  const PhysicalPixelSnap({super.key, super.child});

  @override
  RenderPhysicalPixelSnap createRenderObject(BuildContext context) =>
      RenderPhysicalPixelSnap(
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPhysicalPixelSnap renderObject,
  ) {
    renderObject.devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class RenderPhysicalPixelSnap extends RenderProxyBox {
  RenderPhysicalPixelSnap({required double devicePixelRatio})
    : _devicePixelRatio = devicePixelRatio;

  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value != _devicePixelRatio) {
      _devicePixelRatio = value;
      markNeedsPaint();
    }
  }

  /// The shift applied by the last paint.
  Offset _paintedShift = Offset.zero;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _SettledShiftCheck.watch(this);
  }

  @override
  void detach() {
    _SettledShiftCheck.forget(this);
    super.detach();
  }

  /// Repaints this box if an ancestor moved it without repainting it (a
  /// repaint boundary above it only re-offset, as a sliding page is), which
  /// left it with a stale shift. A box outside the composited scene (a page
  /// kept alive off screen) is not seen, and is checked when it next paints.
  void _checkSettledShift() {
    if (attached && _isComposited() && _shift() != _paintedShift) {
      markNeedsPaint();
    }
  }

  /// Whether this box's last paint is part of the composited scene: the layer
  /// of its nearest repaint boundary is attached to the layer tree. A subtree
  /// its parent stopped painting has a detached layer.
  bool _isComposited() {
    RenderObject? node = this;
    while (node != null && !node.isRepaintBoundary) {
      node = node.parent;
    }
    return node?.layer?.attached ?? false;
  }

  /// The sub-pixel shift that puts this box's origin on a physical pixel, or
  /// zero when the box is not laid out or not purely translated.
  Offset _shift() {
    if (!hasSize || !attached) {
      return Offset.zero;
    }
    final translation = MatrixUtils.getAsTranslation(getTransformTo(null));
    if (translation == null) {
      return Offset.zero;
    }
    double remainder(double logical) {
      final physical = logical * _devicePixelRatio;
      return (physical.roundToDouble() - physical) / _devicePixelRatio;
    }

    return Offset(remainder(translation.dx), remainder(translation.dy));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintedShift = _shift();
    super.paint(context, offset + _paintedShift);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintOffset(
      offset: _paintedShift,
      position: position,
      hitTest: (result, transformed) =>
          super.hitTestChildren(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_paintedShift.dx, _paintedShift.dy, 0, 1);
  }
}

/// Checks every [RenderPhysicalPixelSnap] once the frames stop.
///
/// While something moves, a box re-offset without a repaint is a fraction of
/// a physical pixel off the grid, which motion hides. Checking each box after
/// every frame walked to the root for hundreds of boxes (every grid-fitted
/// icon) and repainted them all on every frame of a slide. Instead, the boxes
/// are checked together when no frame followed for [_settleDelay]: once per
/// animation, repainting only the boxes whose shift changed. Frames that never
/// stop (a video playing, a looping animation) still get a check at least
/// every [_longestWait]. The check never schedules a frame by itself.
abstract final class _SettledShiftCheck {
  static const _settleDelay = Duration(milliseconds: 50);
  static const _longestWait = Duration(milliseconds: 500);
  static final Set<RenderPhysicalPixelSnap> _boxes = {};
  static Timer? _timer;
  static bool _listening = false;

  /// The frame that started the wait for the pending check.
  static Duration? _waitingSince;

  static void watch(RenderPhysicalPixelSnap box) {
    _boxes.add(box);
    if (!_listening) {
      _listening = true;
      SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    }
    _timer ??= Timer(_settleDelay, _check);
  }

  static void forget(RenderPhysicalPixelSnap box) {
    _boxes.remove(box);
    if (_boxes.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _waitingSince = null;
    }
  }

  /// Each frame pushes the pending check back, until it has waited
  /// [_longestWait]: then it runs [_settleDelay] after it was last pushed.
  static void _onFrame(Duration timeStamp) {
    if (_boxes.isEmpty) {
      return;
    }
    final since = _waitingSince ??= timeStamp;
    if (_timer != null && timeStamp - since >= _longestWait) {
      return;
    }
    _timer?.cancel();
    _timer = Timer(_settleDelay, _check);
  }

  static void _check() {
    _timer = null;
    _waitingSince = null;
    for (final box in _boxes.toList()) {
      box._checkSettledShift();
    }
  }
}
