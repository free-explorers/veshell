import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/provider/logs_for_pid.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/meta_window/widget/meta_surface_gaming_overlay.dart';
import 'package:shell/shared/widget/container_with_positionnable_children/container_with_positionnable_children.dart';
import 'package:shell/wayland/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/wayland/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/widget/floatable_window.dart';
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

    return ClipRect(
      child: FocusScope(
        node: persistentFocusNode,
        autofocus: true,
        onFocusChange: (value) {
          if (value) {
            persistentFocusNode.autofocus(primaryFocusNode);
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: window.metaWindowId != null
              ? WithSurfacesWidget(
                  focusNode: primaryFocusNode,
                  window: window,
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
    final isRunning = window.metaWindowId != null;
    final title = window.properties.title;
    return HookBuilder(
      builder: (context) {
        final isHoverState = useState(false);

        return GestureDetector(
          onTertiaryTapUp: (_) {
            ref
                .read(
                  windowManagerProvider.notifier,
                )
                .closeWindow(window.windowId);
          },
          child: MouseRegion(
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
      Consumer(
        builder: (context, subref, child) {
          final displayMode = subref.watch(
            persistentWindowStateProvider(windowId).select(
              (value) => value.displayMode,
            ),
          );
          return SubmenuButton(
            menuChildren: [
              ...DisplayMode.values.map(
                (e) => MenuItemButton(
                  leadingIcon: switch (e) {
                    DisplayMode.maximized =>
                      const Icon(MdiIcons.windowMaximize),
                    DisplayMode.fullscreen => const Icon(MdiIcons.fullscreen),
                    DisplayMode.game => const Icon(MdiIcons.controller),
                    DisplayMode.floating => SvgPicture.asset(
                        'assets/float-symbolic.svg',
                        width: 24,
                        height: 24,
                      ),
                  },
                  onPressed: () {
                    ref
                        .read(persistentWindowStateProvider(windowId).notifier)
                        .setDisplayMode(e);
                  },
                  style: MenuItemButton.styleFrom(
                    foregroundColor: e == displayMode
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  child: Text(e.name),
                ),
              ),
            ],
            child: const Text('Display mode'),
          );
        },
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

class WithSurfacesWidget extends HookConsumerWidget {
  const WithSurfacesWidget({
    required this.window,
    required this.focusNode,
    super.key,
  });
  final FocusNode focusNode;

  final PersistentWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayMode = window.displayMode;

    final dialogWindowList = ref
        .watch(
      dialogSetForWindowProvider(window.windowId),
    )
        .map((element) {
      return ref.watch(dialogWindowStateProvider(element));
    }).toList();

    final activateWindow = useCallback(
      (bool value) {
        final metaWindowToActivate =
            dialogWindowList.lastOrNull?.metaWindowId ?? window.metaWindowId;
        if (metaWindowToActivate != null) {
          final metaWindow =
              ref.read(metaWindowStateProvider(metaWindowToActivate));

          ref.read(waylandManagerProvider.notifier).request(
                ActivateWindowRequest(
                  message: ActivateWindowMessage(
                    surfaceId: metaWindow.surfaceId,
                    activate: value,
                  ),
                ),
              );
        }
      },
      [window.metaWindowId, dialogWindowList],
    );

    useEffect(
      () {
        if (focusNode.hasFocus) {
          activateWindow(true);
        }
        return null;
      },
      [window.metaWindowId],
    );

    useEffect(
      () {
        void callback() {
          activateWindow(focusNode.hasFocus);
        }

        focusNode.addListener(callback);
        return () {
          focusNode.removeListener(callback);
        };
      },
      [focusNode],
    );

    return switch (displayMode) {
      DisplayMode.maximized ||
      DisplayMode
            .fullscreen => // TODO: fix this, it's not working with the new wayland stack, need to find a way to get the surface id from the meta surface and then use that to get the surface from the wayland stack, or just use the meta surface directly, but that would mean we need to change the way we handle surfaces in flutte
        Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return HookBuilder(
                  builder: (context) {
                    useEffect(
                      () {
                        if (constraints
                                .widthConstraints()
                                .maxWidth
                                .isInfinite ||
                            constraints
                                .heightConstraints()
                                .maxHeight
                                .isInfinite) {
                          return null;
                        }
                        WidgetsBinding.instance
                            .addPostFrameCallback((timeStamp) {
                          final geometry = ref.read(
                            metaWindowStateProvider(window.metaWindowId!)
                                .select((value) => value.geometry),
                          );

                          ref
                              .read(
                                metaWindowStateProvider(window.metaWindowId!)
                                    .notifier,
                              )
                              .patch(
                                UpdateGeometry(
                                  id: window.metaWindowId!,
                                  value: Rect.fromLTWH(
                                    geometry!.left,
                                    geometry.top,
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                ),
                              );
                        });
                        return null;
                      },
                      [constraints],
                    );

                    return MetaSurfaceWidget(
                      focusNode: focusNode,
                      metaWindowId: window.metaWindowId!,
                      decorated: false,
                    );
                  },
                );
              },
            ),
            if (dialogWindowList.isNotEmpty) ...[
              const Positioned.fill(child: ColoredBox(color: Colors.black38)),
              ContainerWithPositionnableChildren(
                children: dialogWindowList
                    .map(
                      (e) => FloatableWindow(
                        window: e,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      DisplayMode.game => MetaSurfaceGamingOverlay(
          metaWindowId: window.metaWindowId!,
        ),
      DisplayMode.floating => ContainerWithPositionnableChildren(
          children: [
            FloatableWindow(window: window),
            for (final dialogWindow in dialogWindowList)
              FloatableWindow(window: dialogWindow),
          ],
        ),
    };
  }
}