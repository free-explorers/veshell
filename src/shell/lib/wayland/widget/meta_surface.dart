import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/x11_surface.dart';
import 'package:shell/wayland/widget/xdg_toplevel_surface.dart';

class MetaSurfaceWidget extends HookConsumerWidget {
  const MetaSurfaceWidget({
    required this.surfaceId,
    this.focusNode,
    super.key,
  });
  final SurfaceId surfaceId;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.read(
      wlSurfaceStateProvider(surfaceId).select((value) => value.role),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return HookBuilder(
          builder: (context) {
            useEffect(
              () {
                if (constraints.widthConstraints().maxWidth.isInfinite ||
                    constraints.heightConstraints().maxHeight.isInfinite) {
                  return null;
                }
                ref
                    .read(
                      wlSurfaceStateProvider(surfaceId).notifier,
                    )
                    .resizeSurface(
                      width: constraints.widthConstraints().maxWidth.round(),
                      height: constraints.heightConstraints().maxHeight.round(),
                    );
                return null;
              },
              [constraints],
            );
            return switch (role) {
              SurfaceRole.xdgToplevel => XdgToplevelSurfaceWidget(
                  focusNode: focusNode,
                  surfaceId: surfaceId,
                ),
              SurfaceRole.x11Surface => X11SurfaceWidget(
                  focusNode: focusNode,
                  surfaceId: surfaceId,
                ),
              _ => const SizedBox(),
            };
          },
        );
      },
    );
  }
}
