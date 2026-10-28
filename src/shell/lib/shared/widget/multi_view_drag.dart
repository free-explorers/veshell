import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Flutter keeps a held pointer in its starting view. Bridge shell drags to
/// the other views without changing that gesture's view or coordinate space.
class ShellDragView extends StatefulWidget {
  const ShellDragView({required this.origin, required this.child, super.key});

  final Offset origin;
  final Widget child;

  static final _views = <_ShellDragViewState>{};

  /// The view containing [global] (compositor-global logical coordinates),
  /// other than [excluding], or `null` when no view does.
  static _ShellDragViewState? _viewAt(
    Offset global, {
    _ShellDragViewState? excluding,
  }) {
    for (final view in _views) {
      if (!view.mounted || identical(view, excluding)) continue;
      final size =
          View.of(view.context).physicalSize /
          View.of(view.context).devicePixelRatio;
      if ((view.widget.origin & size).contains(global)) return view;
    }
    return null;
  }

  /// Resolves [global] against every monitor view, or returns `null` when it
  /// is outside all of them.
  static ShellDragLocation? locate(Offset global) {
    final view = _viewAt(global);
    return view == null
        ? null
        : ShellDragLocation._(view, global - view.widget.origin);
  }

  @override
  State<ShellDragView> createState() => _ShellDragViewState();
}

/// The view a held pointer started in.
///
/// Flutter keeps reporting a held pointer's positions in the coordinate space
/// of the view it went down in, even once it is over another monitor.
class ShellDragSource {
  ShellDragSource._(this._view);

  /// The source view of a pointer that went down inside [context].
  static ShellDragSource? of(BuildContext context) {
    final view = context.findAncestorStateOfType<_ShellDragViewState>();
    return view == null ? null : ShellDragSource._(view);
  }

  final _ShellDragViewState _view;

  bool get mounted => _view.mounted;

  /// Converts a position reported by this view to global coordinates.
  Offset toGlobal(Offset position) => position + _view.widget.origin;
}

/// A global position resolved to the monitor view under it.
class ShellDragLocation {
  ShellDragLocation._(this._view, this.position);

  final _ShellDragViewState _view;

  /// The position, local to the view.
  final Offset position;

  /// Converts a position local to this view to global coordinates.
  Offset toGlobal(Offset viewPosition) => viewPosition + _view.widget.origin;

  /// Hit-tests the view at [position]; the path runs innermost first.
  Iterable<HitTestEntry> hitTest() {
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      position,
      View.of(_view.context).viewId,
    );
    return result.path;
  }
}

class _ShellDragViewState extends State<ShellDragView> {
  @override
  void initState() {
    super.initState();
    ShellDragView._views.add(this);
  }

  @override
  void dispose() {
    ShellDragView._views.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

abstract class _RemoteTarget {
  bool get mounted;
  bool accepts(Object data, Offset position);
  void accept(Object data, Offset position);
  void leave(Object data);
}

/// Uses Flutter's normal DragTarget in the source view, and the same callbacks
/// when a shell drag is hit-tested in a different monitor's view.
class ShellDragTarget<T extends Object> extends StatefulWidget {
  const ShellDragTarget({
    required this.builder,
    this.onWillAcceptWithDetails,
    this.onAcceptWithDetails,
    this.onLeave,
    super.key,
  });

  final DragTargetBuilder<T> builder;
  final DragTargetWillAcceptWithDetails<T>? onWillAcceptWithDetails;
  final DragTargetAcceptWithDetails<T>? onAcceptWithDetails;
  final DragTargetLeave<T>? onLeave;

  @override
  State<ShellDragTarget<T>> createState() => _ShellDragTargetState<T>();
}

class _ShellDragTargetState<T extends Object> extends State<ShellDragTarget<T>>
    implements _RemoteTarget {
  T? _remoteCandidate;

  @override
  bool accepts(Object data, Offset position) {
    if (data is! T) return false;
    final accepted =
        widget.onWillAcceptWithDetails?.call(
          DragTargetDetails<T>(data: data, offset: position),
        ) ??
        true;
    if (accepted && _remoteCandidate != data) {
      setState(() => _remoteCandidate = data);
    }
    return accepted;
  }

  @override
  void accept(Object data, Offset position) {
    setState(() => _remoteCandidate = null);
    widget.onAcceptWithDetails?.call(
      DragTargetDetails<T>(data: data as T, offset: position),
    );
  }

  @override
  void leave(Object data) {
    setState(() => _remoteCandidate = null);
    widget.onLeave?.call(data as T);
  }

  @override
  Widget build(BuildContext context) => MetaData(
    metaData: this,
    behavior: HitTestBehavior.translucent,
    child: DragTarget<T>(
      onWillAcceptWithDetails: widget.onWillAcceptWithDetails,
      onAcceptWithDetails: widget.onAcceptWithDetails,
      onLeave: widget.onLeave,
      builder: (context, candidates, rejected) => widget.builder(context, [
        ...candidates,
        if (_remoteCandidate != null) _remoteCandidate,
      ], rejected),
    ),
  );
}

/// One bridge per active draggable. Positions supplied by Flutter remain
/// source-view-local even outside that monitor, as guaranteed by the embedder.
class ShellDragSession {
  ShellDragSession(BuildContext context, this.data, this.feedback)
    : _source = context.findAncestorStateOfType<_ShellDragViewState>();

  final Object data;
  final Widget feedback;
  final _ShellDragViewState? _source;
  _ShellDragViewState? _destination;
  OverlayEntry? _preview;
  _RemoteTarget? _target;
  Offset _position = Offset.zero;

  void update(Offset sourcePosition) {
    final source = _source;
    if (source == null || !source.mounted) return;
    final global = sourcePosition + source.widget.origin;
    final destination = ShellDragView._viewAt(global, excluding: source);
    if (!identical(destination, _destination)) {
      _removePreview();
      _destination = destination;
    }
    if (destination == null) {
      _leaveTarget();
      return;
    }
    _RemoteTarget? nextTarget;
    _position = global - destination.widget.origin;
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      _position,
      View.of(destination.context).viewId,
    );
    for (final entry in result.path) {
      final renderObject = entry.target;
      if (renderObject is RenderMetaData &&
          renderObject.metaData is _RemoteTarget) {
        final target = renderObject.metaData as _RemoteTarget;
        if (target.accepts(data, _position)) {
          nextTarget = target;
          break;
        }
      }
    }
    if (!identical(nextTarget, _target)) {
      _leaveTarget();
      _target = nextTarget;
    }
    if (_preview == null) {
      final overlay = Overlay.maybeOf(destination.context, rootOverlay: true);
      if (overlay == null) return;
      _preview = OverlayEntry(
        builder: (_) => Positioned(
          left: _position.dx,
          top: _position.dy,
          child: IgnorePointer(child: feedback),
        ),
      );
      overlay.insert(_preview!);
    } else {
      _preview!.markNeedsBuild();
    }
  }

  bool drop() {
    final target = _target;
    _target = null;
    dispose();
    if (target == null || !target.mounted) return false;
    target.accept(data, _position);
    return true;
  }

  void _removePreview() {
    final preview = _preview;
    if (preview != null) {
      preview
        ..remove()
        ..dispose();
      _preview = null;
    }
  }

  void dispose() {
    _removePreview();
    _leaveTarget();
    _destination = null;
  }

  void _leaveTarget() {
    final target = _target;
    _target = null;
    if (target != null && target.mounted) target.leave(data);
  }
}
