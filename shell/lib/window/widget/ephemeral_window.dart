import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/x11_surface.dart';
import 'package:shell/wayland/widget/xdg_toplevel_surface.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/dialog_list_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';

/// Tileable Window that persist when closed
class EphemeralWindowWidget extends HookConsumerWidget {
  /// Const constructor
  const EphemeralWindowWidget({
    required this.windowId,
    required this.focusNode,
    super.key,
  });

  /// The id of the wayland surface
  final EphemeralWindowId windowId;
  final FocusNode focusNode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(ephemeralWindowStateProvider(windowId));

    final dialogWindowIdSet = ref.watch(
      dialogListForWindowProvider.select((value) => value.get(windowId)),
    );
    final dialogWindowList = <DialogWindow>[];
    for (final windowId in dialogWindowIdSet) {
      final dialogWindow = ref.read(dialogWindowStateProvider(windowId));
      dialogWindowList.add(dialogWindow);
    }

    useEffect(
      () {
        if (window.surfaceId != null) {
          ref.read(waylandManagerProvider.notifier).request(
                ActivateWindowRequest(
                  message: ActivateWindowMessage(
                    surfaceId: window.surfaceId!,
                    activate: true,
                  ),
                ),
              );
        }
        return null;
      },
      [window.surfaceId],
    );

    if (window.surfaceId != null) {
      return Focus(
        focusNode: focusNode,
        onFocusChange: (value) {
          if (window.surfaceId != null) {
            ref.read(waylandManagerProvider.notifier).request(
                  ActivateWindowRequest(
                    message: ActivateWindowMessage(
                      surfaceId: window.surfaceId!,
                      activate: focusNode.hasFocus,
                    ),
                  ),
                );
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return HookBuilder(
              builder: (context) {
                useEffect(
                  () {
                    ref
                        .read(
                          wlSurfaceStateProvider(window.surfaceId!).notifier,
                        )
                        .resizeSurface(
                          width:
                              constraints.widthConstraints().maxWidth.round(),
                          height:
                              constraints.heightConstraints().maxHeight.round(),
                        );
                    return null;
                  },
                  [constraints],
                );
                return Builder(
                  builder: (context) {
                    final role = ref.read(
                      wlSurfaceStateProvider(window.surfaceId!)
                          .select((value) => value.role),
                    );

                    if (role == SurfaceRole.xdgToplevel) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          XdgToplevelSurfaceWidget(
                            surfaceId: window.surfaceId!,
                          ),
                          if (dialogWindowList.isNotEmpty)
                            const ColoredBox(color: Colors.black38),
                          if (dialogWindowList.isNotEmpty)
                            for (final dialog in dialogWindowList)
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: XdgToplevelSurfaceWidget(
                                    surfaceId: dialog.surfaceId,
                                  ),
                                ),
                              ),
                        ],
                      );
                    } else if (role == SurfaceRole.x11Surface) {
                      return X11SurfaceWidget(
                        surfaceId: window.surfaceId!,
                      );
                    } else {
                      assert(false, 'Unsupported role: $role');
                      return const SizedBox();
                    }
                  },
                );
              },
            );
          },
        ),
      );
    } else {
      return Container();
    }
  }
}
