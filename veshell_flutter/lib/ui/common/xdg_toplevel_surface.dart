import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zenith/ui/common/state/surface_state.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';

class XdgToplevelSurface extends ConsumerWidget {
  final int viewId;

  const XdgToplevelSurface({
    required super.key,
    required this.viewId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VisibilityDetector(
      key: ValueKey(viewId),
      onVisibilityChanged: (VisibilityInfo info) {
        bool visible = info.visibleFraction > 0;
        if (ref.context.mounted) {
          ref.read(xdgToplevelStatesProvider(viewId).notifier).visible = visible;
        }
      },
      child: _SurfaceFocus(
        viewId: viewId,
        child: _PointerListener(
          viewId: viewId,
          child: ref.watch(surfaceWidgetProvider(viewId)),
        ),
      ),
    );
  }
}

class _SurfaceFocus extends ConsumerWidget {
  final int viewId;
  final Widget child;

  const _SurfaceFocus({
    required this.viewId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.tab): DisableFocusTraversalIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): DisableFocusTraversalIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): DisableFocusTraversalIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): DisableFocusTraversalIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown): DisableFocusTraversalIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): DisableFocusTraversalIntent(),
      },
      child: Actions(
        actions: {
          DisableFocusTraversalIntent: DisableFocusTraversalAction(),
        },
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final focusNode = ref.watch(xdgToplevelStatesProvider(viewId)).focusNode;

            return Focus(
              focusNode: focusNode,
              child: child!,
            );
          },
          child: child,
        ),
      ),
    );
  }
}

class _PointerListener extends ConsumerWidget {
  final int viewId;
  final Widget child;

  const _PointerListener({
    Key? key,
    required this.viewId,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Listener(
      onPointerDown: (_) => ref.read(xdgToplevelStatesProvider(viewId)).focusNode.requestFocus(),
      child: child,
    );
  }
}

class DisableFocusTraversalIntent extends Intent {}

class DisableFocusTraversalAction extends Action<DisableFocusTraversalIntent> {
  @override
  Object? invoke(DisableFocusTraversalIntent intent) => null;

  /// The embedder will only send key events to Wayland clients if they are not handled by Flutter.
  @override
  bool consumesKey(DisableFocusTraversalIntent intent) => false;
}
