import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/util/paint_placement.dart';
import 'package:shell/wayland/model/wl_surface.dart';

/// Reports that [child] displays the client surface [surfaceId].
///
/// Every place the shell draws a client texture wraps it in one: the
/// [SurfaceVisibilityTracker] decides after each frame which of them are
/// actually painted on screen.
class SurfaceVisibilityProbe extends SingleChildRenderObjectWidget {
  const SurfaceVisibilityProbe({
    required this.surfaceId,
    required super.child,
    super.key,
  });

  final SurfaceId surfaceId;

  @override
  RenderSurfaceVisibilityProbe createRenderObject(BuildContext context) =>
      RenderSurfaceVisibilityProbe(surfaceId: surfaceId);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSurfaceVisibilityProbe renderObject,
  ) {
    renderObject.surfaceId = surfaceId;
  }
}

class RenderSurfaceVisibilityProbe extends RenderProxyBox {
  RenderSurfaceVisibilityProbe({required SurfaceId surfaceId})
    : _surfaceId = surfaceId;

  SurfaceId _surfaceId;
  SurfaceId get surfaceId => _surfaceId;
  set surfaceId(SurfaceId value) {
    if (_surfaceId == value) return;
    _surfaceId = value;
    SurfaceVisibilityTracker.instance.markDirty();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    SurfaceVisibilityTracker.instance._probes.add(this);
    SurfaceVisibilityTracker.instance.markDirty();
  }

  @override
  void detach() {
    SurfaceVisibilityTracker.instance._probes.remove(this);
    SurfaceVisibilityTracker.instance.markDirty();
    super.detach();
  }
}

/// The surfaces the shell displays, sent to the compositor when they change.
///
/// Evaluated after every frame: a surface is visible when one of its probes
/// is painted by its ancestors, not clipped away and not fully transparent
/// (the same rules the probe uses for `painted`).
class SurfaceVisibilityTracker {
  SurfaceVisibilityTracker._();

  static final instance = SurfaceVisibilityTracker._();

  final Set<RenderSurfaceVisibilityProbe> _probes = {};
  void Function(List<int> visible)? _send;
  Set<int>? _lastSent;
  bool _scheduled = false;
  bool _listening = false;

  /// Starts reporting through [send], sending the current state on the next
  /// frame. The compositor treats every surface as visible until the first
  /// report.
  void start(void Function(List<int> visible) send) {
    _send = send;
    _lastSent = null;
    if (!_listening) {
      _listening = true;
      SchedulerBinding.instance.addPersistentFrameCallback((_) => markDirty());
    }
    markDirty();
  }

  /// Re-evaluates after the current (or next) frame.
  void markDirty() {
    if (_send == null || _scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _evaluate();
    });
  }

  void _evaluate() {
    final send = _send;
    if (send == null) return;
    final visible = <int>{};
    for (final probe in _probes) {
      if (!probe.attached || !probe.hasSize || probe.size.isEmpty) continue;
      final placement = paintPlacement(probe);
      if (!placement.painted ||
          placement.visibleRect == null ||
          placement.opacity <= 0.01) {
        continue;
      }
      visible.add(probe.surfaceId);
    }
    final last = _lastSent;
    if (last != null && const SetEquality<int>().equals(last, visible)) {
      return;
    }
    _lastSent = visible;
    send(visible.toList()..sort());
  }
}
