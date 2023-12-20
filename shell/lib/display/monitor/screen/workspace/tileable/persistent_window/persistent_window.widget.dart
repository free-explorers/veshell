import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/tileable.widget.dart';
import 'package:shell/manager/wayland/request/resize_window/resize_window.model.serializable.dart';
import 'package:shell/manager/wayland/surface/xdg_toplevel/xdg_toplevel_surface.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';
import 'package:shell/manager/window/window.manager.dart';
import 'package:shell/manager/window/window.model.dart';

/// Tileable Window that persist when closed
class PersistentWindowTileable extends Tileable {
  /// Const constructor
  const PersistentWindowTileable({required this.windowId, super.key});

  /// The id of the wayland surface
  final WindowId windowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(windowStateProvider(windowId)) as PersistentWindow;

    if (window.surfaceId != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return HookBuilder(
            builder: (context) {
              useEffect(
                () {
                  ref.read(waylandManagerProvider.notifier).request(
                        ResizeWindowRequest(
                          message: ResizeWindowMessage(
                            surfaceId: window.surfaceId!,
                            width:
                                constraints.widthConstraints().maxWidth.round(),
                            height: constraints
                                .heightConstraints()
                                .maxHeight
                                .round(),
                          ),
                        ),
                      );
                  return null;
                },
                [constraints],
              );
              return XdgToplevelSurfaceWidget(
                surfaceId: window.surfaceId!,
              );
            },
          );
        },
      );
    } else {
      return Container();
    }
  }

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef ref) {
    final window = ref.watch(windowStateProvider(windowId)) as PersistentWindow;

    final title = window.title;
    return Tab(child: Text(title));
  }
}
