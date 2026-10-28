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
    _watchShift();
  }

  /// An ancestor can move without repainting this box (a repaint boundary
  /// above it is only re-offset), which would keep a stale shift. Check after
  /// every frame and repaint only when the remainder actually changed. This
  /// never schedules a frame by itself.
  void _watchShift() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached) {
        return;
      }
      if (_shift() != _paintedShift) {
        markNeedsPaint();
      }
      _watchShift();
    }, debugLabel: 'PhysicalPixelSnap');
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
