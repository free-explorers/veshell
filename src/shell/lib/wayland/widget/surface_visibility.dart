import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/util/paint_placement.dart';
import 'package:shell/wayland/model/wl_surface.dart';

/// Marks the client surfaces below it as needing only a low frame rate while
/// shown: a paused game behind its frost. The compositor then paces their
/// frame callbacks, presentation feedback, commits and redraws down.
class SurfaceFrameRateLimit extends InheritedWidget {
  const SurfaceFrameRateLimit({
    required this.limited,
    required super.child,
    super.key,
  });

  final bool limited;

  /// Whether the surfaces at [context] are frame-rate limited.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SurfaceFrameRateLimit>()
          ?.limited ??
      false;

  @override
  bool updateShouldNotify(SurfaceFrameRateLimit oldWidget) =>
      limited != oldWidget.limited;
}

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
      RenderSurfaceVisibilityProbe(
        surfaceId: surfaceId,
        limited: SurfaceFrameRateLimit.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSurfaceVisibilityProbe renderObject,
  ) {
    renderObject
      ..surfaceId = surfaceId
      ..limited = SurfaceFrameRateLimit.of(context);
  }
}

class RenderSurfaceVisibilityProbe extends RenderProxyBox {
  RenderSurfaceVisibilityProbe({
    required SurfaceId surfaceId,
    required bool limited,
  }) : _surfaceId = surfaceId,
       _limited = limited;

  SurfaceId _surfaceId;
  SurfaceId get surfaceId => _surfaceId;
  set surfaceId(SurfaceId value) {
    if (_surfaceId == value) return;
    _surfaceId = value;
    SurfaceVisibilityTracker.instance.markDirty();
  }

  bool _limited;
  bool get limited => _limited;
  set limited(bool value) {
    if (_limited == value) return;
    _limited = value;
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
/// (the same rules the probe uses for `painted`). A limited surface (a
/// paused game) is reported limited whether it is painted or not. A surface
/// shown both limited and at full rate somewhere counts as full rate.
class SurfaceVisibilityTracker {
  SurfaceVisibilityTracker._();

  static final instance = SurfaceVisibilityTracker._();

  final Set<RenderSurfaceVisibilityProbe> _probes = {};
  void Function(List<int> visible, List<int> limited)? _send;
  ({Set<int> visible, Set<int> limited})? _lastSent;
  bool _scheduled = false;
  bool _listening = false;
  Set<int> _pausedGames = const {};

  /// Surfaces limited wherever they are, mounted or not: the paused games
  /// (see `pausedGameSurfacesProvider`). A paused game on a workspace that is
  /// not shown has no probe to report it.
  Set<int> get pausedGames => _pausedGames;
  set pausedGames(Set<int> surfaces) {
    _pausedGames = surfaces;
    markDirty();
  }

  /// Starts reporting through [send], sending the current state on the next
  /// frame. The compositor treats every surface as visible until the first
  /// report.
  void start(void Function(List<int> visible, List<int> limited) send) {
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
    final limited = <int>{};
    for (final probe in _probes) {
      if (!probe.attached) continue;
      // A paused game stays limited wherever it is: on a workspace that is
      // not shown it is not painted, but reporting it hidden would only slow
      // its frame callbacks, which a game with vsync off ignores. Limited, its
      // commits are held to the low rate too.
      if (probe.limited) {
        limited.add(probe.surfaceId);
        continue;
      }
      if (!probe.hasSize || probe.size.isEmpty) continue;
      final placement = paintPlacement(probe);
      if (!placement.painted ||
          placement.visibleRect == null ||
          placement.opacity <= 0.01) {
        continue;
      }
      visible.add(probe.surfaceId);
    }
    limited
      ..addAll(_pausedGames)
      ..removeAll(visible);
    final last = _lastSent;
    const equality = SetEquality<int>();
    if (last != null &&
        equality.equals(last.visible, visible) &&
        equality.equals(last.limited, limited)) {
      return;
    }
    _lastSent = (visible: visible, limited: limited);
    send(visible.toList()..sort(), limited.toList()..sort());
  }
}
