import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/provider/logs_for_pid.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/wayland/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/x11_surface.dart';
import 'package:shell/wayland/widget/xdg_toplevel_surface.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
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
    required super.isSelected,
    super.onGrabFocus,
    super.key,
  });

  /// The id of the wayland surface
  final PersistentWindowId windowId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(persistentWindowStateProvider(windowId));

    final persistentFocusNode = useFocusScopeNode(
      debugLabel: 'PersistentFocusNode ${window.properties.title}',
    );

    final primaryFocusNode = useFocusNode(
      debugLabel: 'PrimaryFocusNode ${window.properties.title}',
    );

    useEffect(
      () {
        persistentFocusNode
          ..canRequestFocus = isSelected
          ..descendantsAreFocusable = isSelected;
        if (isSelected) {
          if (persistentFocusNode.focusedChild != null) {
            persistentFocusNode.focusedChild!.requestFocus();
          } else {
            persistentFocusNode.requestFocus();
          }
        }
        return null;
      },
      [isSelected],
    );

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
        if (isSelected && window.surfaceId != null) {
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

    return ClipRect(
      child: FocusScope(
        node: persistentFocusNode,
        autofocus: true,
        onFocusChange: (value) {
          if (value) {
            persistentFocusNode.autofocus(primaryFocusNode);
          }
          /*  focusLog.info(
            'persistentFocusNode.onFocusChange for ${window.properties.title} $persistentFocusNode',
          ); */

          /* if (value && !isSelected) {
            focusLog.info('onGrabFocus for ${window.properties.title}');
            onGrabFocus?.call();
          } */
          if (window.surfaceId != null) {
            ref.read(waylandManagerProvider.notifier).request(
                  ActivateWindowRequest(
                    message: ActivateWindowMessage(
                      surfaceId: window.surfaceId!,
                      activate: value,
                    ),
                  ),
                );
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: window.surfaceId != null
              ? surfacesWidget(
                  focusNode: primaryFocusNode,
                  window: window,
                  dialogWindowList: dialogWindowList,
                )
              : WindowPlaceholder(
                  isSelected: isSelected,
                  focusNode: primaryFocusNode,
                  window: window,
                  onTap: () {
                    primaryFocusNode.requestFocus();
                    ref
                        .read(
                          persistentWindowStateProvider(windowId).notifier,
                        )
                        .launchSelf();
                  },
                ),
        ),
      ),
    );
  }

  @override
  Widget buildPanelWidget(
    BuildContext context,
    WidgetRef ref,
  ) {
    final window = ref.watch(persistentWindowStateProvider(windowId));
    final isRunning = window.surfaceId != null;
    final title = window.properties.title;
    return HookBuilder(
      builder: (context) {
        final isHoverState = useState(false);

        return MouseRegion(
          onEnter: (event) => isHoverState.value = true,
          onExit: (event) => isHoverState.value = false,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Opacity(
              opacity: isRunning ? 1 : 0.7,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: isRunning
                          ? AppIconById(id: window.properties.appId)
                          : ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0, //
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 1, 0,
                              ]),
                              child: AppIconById(id: window.properties.appId),
                            ),
                    ),
                    const SizedBox(
                      width: 16,
                    ),
                    Flexible(
                      child: Text(
                        title ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    SizedBox(
                      width: 32,
                      child: isSelected || isHoverState.value
                          ? IconButton(
                              visualDensity: VisualDensity.compact,
                              iconSize: 16,
                              onPressed: () {
                                ref
                                    .read(
                                      windowManagerProvider.notifier,
                                    )
                                    .closeWindow(window.windowId);
                              },
                              icon: const Icon(MdiIcons.close),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  List<Widget> buildMenuChildren(BuildContext context, WidgetRef ref) {
    return [
      MenuItemButton(
        onPressed: () {
          final pid = ref.read(persistentWindowStateProvider(windowId)).pid;
          if (pid != null) {
            ref.read(logsForPidProvider(pid).notifier).openLogsDialog(context);
          }
        },
        leadingIcon: const Icon(MdiIcons.headCog),
        child: const Text('Show execution logs'),
      ),
      MenuItemButton(
        onPressed: () {
          ref
              .read(
                windowManagerProvider.notifier,
              )
              .closeWindow(windowId);
        },
        leadingIcon: const Icon(MdiIcons.close),
        child: const Text('Close'),
      ),
    ];
  }
}

class surfacesWidget extends HookConsumerWidget {
  const surfacesWidget({
    required this.window,
    required this.dialogWindowList,
    this.focusNode,
    super.key,
  });
  final FocusNode? focusNode;

  final PersistentWindow window;
  final List<DialogWindow> dialogWindowList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
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
                      width: constraints.widthConstraints().maxWidth.round(),
                      height: constraints.heightConstraints().maxHeight.round(),
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
                        focusNode: dialogWindowList.isEmpty ? focusNode : null,
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
                                focusNode: dialog == dialogWindowList.last
                                    ? focusNode
                                    : null,
                                surfaceId: dialog.surfaceId,
                              ),
                            ),
                          ),
                    ],
                  );
                } else if (role == SurfaceRole.x11Surface) {
                  return X11SurfaceWidget(
                    focusNode: focusNode,
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
    );
  }
}
