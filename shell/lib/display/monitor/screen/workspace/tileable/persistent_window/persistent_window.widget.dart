import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/tileable.widget.dart';
import 'package:shell/manager/surface/xdg_toplevel/xdg_toplevel.provider.dart';
import 'package:shell/manager/surface/xdg_toplevel/xdg_toplevel_surface.dart';
import 'package:shell/manager/wayland/request/resize_window/resize_window.model.serializable.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

/// Tileable Window that persist when closed
class PersistentWindowTileable extends Tileable {
  /// Const constructor
  const PersistentWindowTileable({required this.surfaceId, super.key});

  /// The id of the wayland surface
  final int surfaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return HookBuilder(
          builder: (context) {
            useEffect(
              () {
                ref.read(waylandManagerProvider.notifier).request(
                      ResizeWindowRequest(
                        message: ResizeWindowMessage(
                          surfaceId: surfaceId,
                          width:
                              constraints.widthConstraints().maxWidth.round(),
                          height:
                              constraints.heightConstraints().maxHeight.round(),
                        ),
                      ),
                    );
                return null;
              },
              [constraints],
            );
            return XdgToplevelSurface(
              surfaceId: surfaceId,
            );
          },
        );
      },
    );
  }

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef ref) {
    final title = ref.watch(
      xdgToplevelStatesProvider(surfaceId).select((value) => value.title),
    );
    return Tab(child: Text(title));
  }
}
