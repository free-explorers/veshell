import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/x11_surface_state.dart';
import 'package:shell/wayland/provider/xdg_surface_state.dart';
import 'package:shell/wayland/widget/surface.dart';
import 'package:shell/wayland/widget/surface/pointer_listener.dart';
import 'package:shell/wayland/widget/surface/surface_focus.dart';
import 'package:shell/wayland/widget/surface/xdg_popup/popup.dart';
import 'package:visibility_detector/visibility_detector.dart';

class X11SurfaceWidget extends ConsumerWidget {
  const X11SurfaceWidget({
    required this.surfaceId,
    super.key,
  });

  final SurfaceId surfaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final x11SurfaceId = ref.watch(
      x11SurfaceIdByWlSurfaceIdProvider(surfaceId),
    );

    final overrideRedirect = ref.watch(
      x11SurfaceStateProvider(x11SurfaceId).select(
        (value) => value.overrideRedirect,
      ),
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
              (x11Surface) => x11Surface.mapped,
            ),
          ),
        )
        .map(
          (x11SurfaceId) => ref.watch(
            x11SurfaceStateProvider(x11SurfaceId).select(
              (x11Surface) => (x11Surface.surfaceId, x11Surface.geometry),
            ),
          ),
        )
        .toList();

    return VisibilityDetector(
      key: ValueKey(surfaceId),
      onVisibilityChanged: (VisibilityInfo info) {
        final visible = info.visibleFraction > 0;
        if (ref.context.mounted) {
          /* ref.read(xdgToplevelStateProvider(surfaceId).notifier).visible =
              visible; */
        }
      },
      child: SurfaceFocus(
        child: Stack(
          children: [
            PointerListener(
              enabled: !overrideRedirect,
              surfaceId: surfaceId,
              child: SurfaceWidget(
                surfaceId: surfaceId,
              ),
            ),
            for (final (surfaceId, geometry) in children)
              Positioned(
                left: geometry.left,
                top: geometry.top,
                child: X11SurfaceWidget(
                  surfaceId: surfaceId!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
