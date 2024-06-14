import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/wayland/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/wayland/model/request/resize_window/resize_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/x11_surface.dart';
import 'package:shell/wayland/widget/xdg_toplevel_surface.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/dialog_list_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/workspace/widget/tileable/persistent_window/window_placeholder.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';

/// Tileable Window that persist when closed
class PersistentWindowTileable extends Tileable {
  /// Const constructor
  const PersistentWindowTileable({
    required this.windowId,
    required super.isFocused,
    super.key,
  });

  /// The id of the wayland surface
  final PersistentWindowId windowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(persistentWindowStateProvider(windowId));
    final dialogWindowIdSet = ref.watch(
      dialogListForWindowProvider.select((value) => value.get(windowId)),
    );
    final dialogWindowList = <DialogWindow>[];
    for (final windowId in dialogWindowIdSet) {
      final dialogWindow = ref.read(dialogWindowStateProvider(windowId));
      dialogWindowList.add(dialogWindow);
    }
    final tileableFocusNode =
        useFocusNode(debugLabel: 'PersistentWindowTileable');

    useEffect(
      () {
        if (isFocused) {
          tileableFocusNode.requestFocus();
        }
        return null;
      },
      [isFocused],
    );

    useEffect(
      () {
        if (isFocused && window.surfaceId != null) {
          ref.read(waylandManagerProvider.notifier).request(
                ActivateWindowRequest(
                  message: ActivateWindowMessage(
                    surfaceId: window.surfaceId!,
                    activate: tileableFocusNode.hasFocus,
                  ),
                ),
              );
        }
        return null;
      },
      [window.surfaceId],
    );

    void onTileableFocusChange() {
      if (window.surfaceId != null) {
        ref.read(waylandManagerProvider.notifier).request(
              ActivateWindowRequest(
                message: ActivateWindowMessage(
                  surfaceId: window.surfaceId!,
                  activate: tileableFocusNode.hasFocus,
                ),
              ),
            );
      }
    }

    useEffect(
      () {
        tileableFocusNode.addListener(onTileableFocusChange);
        return () {
          tileableFocusNode.removeListener(onTileableFocusChange);
        };
      },
      [tileableFocusNode, window.surfaceId],
    );
    if (window.surfaceId != null) {
      return Focus(
        autofocus: true,
        focusNode: tileableFocusNode,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return HookBuilder(
              builder: (context) {
                useEffect(
                  () {
                    ref.read(waylandManagerProvider.notifier).request(
                          ResizeWindowRequest(
                            message: ResizeWindowMessage(
                              surfaceId: window.surfaceId!,
                              width: constraints
                                  .widthConstraints()
                                  .maxWidth
                                  .round(),
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
                            for (final dialog in dialogWindowList)
                              XdgToplevelSurfaceWidget(
                                surfaceId: dialog.surfaceId,
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
      return WindowPlaceholder(
        windowId: windowId,
      );
    }
  }

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef ref) {
    final window = ref.watch(persistentWindowStateProvider(windowId));

    final title = window.properties.title;
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Row(
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: AppIconById(id: window.properties.appId),
          ),
          const SizedBox(
            width: 16,
          ),
          Text(title ?? 'Unknown'),
          const SizedBox(
            width: 16,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: () {
              ref
                  .read(
                    windowManagerProvider.notifier,
                  )
                  .closeWindow(window.windowId);
            },
            icon: Icon(MdiIcons.close),
          ),
        ],
      ),
    );
  }
}
