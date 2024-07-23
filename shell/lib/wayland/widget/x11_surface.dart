import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/x11_surface.dart';
import 'package:shell/wayland/provider/x11_surface_state.dart';
import 'package:shell/wayland/widget/surface.dart';
import 'package:shell/wayland/widget/surface/pointer_listener.dart';
import 'package:shell/wayland/widget/surface/surface_focus.dart';

class X11SurfaceWidget extends ConsumerWidget {
  const X11SurfaceWidget({
    required this.surfaceId,
    this.focusNode,
    super.key,
  });
  final SurfaceId surfaceId;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final x11SurfaceId = ref.watch(
      x11SurfaceIdByWlSurfaceIdProvider(surfaceId),
    );

    final parent = ref.watch(
      x11SurfaceStateProvider(x11SurfaceId).select(
        (value) => value.parent,
      ),
    );

    final isRootWindow = parent == null;

    final widget = switch (isRootWindow) {
      true => X11RootWindow(
          focusNode: focusNode,
          surfaceId: surfaceId,
        ),
      false => X11ChildWindow(surfaceId: surfaceId),
    };

    return widget;
  }
}

class X11RootWindow extends ConsumerWidget {
  const X11RootWindow({
    required this.surfaceId,
    this.focusNode,
    super.key,
  });
  final SurfaceId surfaceId;
  final FocusNode? focusNode;

  void _collectChildren(
    List<X11SurfaceId> ids,
    WidgetRef ref,
    SurfaceId surfaceId,
  ) {
    final x11SurfaceId = ref.watch(
      x11SurfaceIdByWlSurfaceIdProvider(surfaceId),
    );

    final children = ref
        .watch(
          x11SurfaceStateProvider(x11SurfaceId).select(
            (value) => value.children,
          ),
        )
        .where(
          (x11SurfaceId) => ref.watch(
            x11SurfaceStateProvider(x11SurfaceId).select(
              (value) => value.mapped,
            ),
          ),
        )
        .map(
          (x11SurfaceId) => ref.watch(
            x11SurfaceStateProvider(x11SurfaceId).select(
              (value) => value.surfaceId,
            ),
          )!,
        );

    ids.addAll(children);

    for (final surfaceId in children) {
      _collectChildren(ids, ref, surfaceId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = <SurfaceId>[];
    _collectChildren(children, ref, surfaceId);

    return SurfaceFocus(
      focusNode: focusNode,
      child: Stack(
        children: [
          ActivateSurfaceOnPointerDown(
            surfaceId: surfaceId,
            child: SurfaceWidget(
              surfaceId: surfaceId,
            ),
          ),
          for (final surfaceId in children)
            X11ChildWindow(surfaceId: surfaceId),
        ],
      ),
    );
  }
}

class X11ChildWindow extends ConsumerWidget {
  const X11ChildWindow({
    required this.surfaceId,
    super.key,
  });
  final SurfaceId surfaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Positioner(
      surfaceId: surfaceId,
      child: SurfaceFocus(
        child: ActivateSurfaceOnPointerDown(
          surfaceId: surfaceId,
          child: SurfaceWidget(
            surfaceId: surfaceId,
          ),
        ),
      ),
    );
  }
}

class _Positioner extends HookConsumerWidget {
  const _Positioner({
    required this.surfaceId,
    required this.child,
  });

  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final x11SurfaceId = ref.watch(
      x11SurfaceIdByWlSurfaceIdProvider(surfaceId),
    );

    final geometry = ref.watch(
      x11SurfaceStateProvider(x11SurfaceId).select(
        (value) => value.geometry,
      ),
    );

    return Positioned(
      left: geometry.left,
      top: geometry.top,
      child: child,
    );
  }
}
