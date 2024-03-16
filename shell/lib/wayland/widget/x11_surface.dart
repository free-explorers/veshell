import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/x11_surface.dart';
import 'package:shell/wayland/provider/x11_surface_state.dart';
import 'package:shell/wayland/widget/surface.dart';
import 'package:shell/wayland/widget/surface/pointer_listener.dart';
import 'package:shell/wayland/widget/surface/surface_focus.dart';
import 'package:visibility_detector/visibility_detector.dart';

class X11SurfaceWidget extends ConsumerWidget {
  final SurfaceId surfaceId;

  const X11SurfaceWidget({
    required this.surfaceId,
    super.key,
  });

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
      true => X11RootWindow(surfaceId: surfaceId),
      false => X11ChildWindow(surfaceId: surfaceId),
    };

    return VisibilityDetector(
      key: ValueKey(surfaceId),
      onVisibilityChanged: (VisibilityInfo info) {
        final visible = info.visibleFraction > 0;
        if (ref.context.mounted) {
          /* ref.read(xdgToplevelStateProvider(surfaceId).notifier).visible =
              visible; */
        }
      },
      child: widget,
    );
  }
}

class X11RootWindow extends ConsumerWidget {
  final SurfaceId surfaceId;

  const X11RootWindow({
    super.key,
    required this.surfaceId,
  });

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
  final SurfaceId surfaceId;

  const X11ChildWindow({
    super.key,
    required this.surfaceId,
  });

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
