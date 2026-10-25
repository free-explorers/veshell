import 'dart:async';
import 'dart:math' as math;

import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/file_chooser/provider/file_chooser_for_window.dart';
import 'package:shell/file_chooser/widget/file_chooser_dialog.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_for_id.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_popup.dart';
import 'package:shell/meta_window/widget/meta_surface_decoration.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/widget/container_with_positionnable_children/container_with_positionnable_children.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/widget/floatable_window.dart';

/// The floating display mode's window stack.
///
/// Every native window owned by [parentWindowId] — the displayed window and
/// each attached dialog, regular top-levels included — is an independently
/// decorated, positionable and resizable [FloatableWindow]. They are all
/// siblings in one [ContainerWithPositionnableChildren], sharing one drag/resize
/// controller and one z-order.
///
/// The stack is ordered bottom-to-top: a window that opens goes above the
/// others and pressing on one raises it. Selecting the tile activates the
/// topmost window. The trusted file chooser keeps its own modal presentation
/// above the stack.
class FloatingWindowArea extends HookConsumerWidget {
  const FloatingWindowArea({
    required this.parentWindowId,
    required this.mainMetaWindowId,
    required this.background,
    this.focusNode,
    this.isSelected = false,
    super.key,
  });

  /// The tile that owns the windows and the chooser.
  final WindowId parentWindowId;

  /// The tile's displayed window, initially at the bottom of the stack, or
  /// `null` while the tile shows no native window. It can be raised like any
  /// other window.
  final MetaWindowId? mainMetaWindowId;

  /// Shown behind the floating windows, typically the tile's placeholder.
  final Widget background;

  /// The tile's focus target. Attached here because floating mode does not
  /// build `WindowWidget`, whose focus node normally anchors navigation
  /// shortcuts to the workspace.
  final FocusNode? focusNode;

  /// Whether the tile is selected. Its topmost window is activated when it is.
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialogWindowIds = ref.watch(
      dialogSetForWindowProvider(parentWindowId),
    );
    final chooser = ref.watch(fileChooserForWindowProvider(parentWindowId));

    final mainMetaWindowId = this.mainMetaWindowId;
    final mainMetaWindow = mainMetaWindowId == null
        ? null
        : _watchMetaWindow(ref, mainMetaWindowId);
    final metaWindows = <MetaWindowId, MetaWindow>{};
    if (mainMetaWindow != null) {
      metaWindows[mainMetaWindow.id] = mainMetaWindow;
    }
    for (final dialogWindowId in dialogWindowIds) {
      final metaWindow = _readDialogMetaWindow(ref, dialogWindowId);
      if (metaWindow != null && metaWindow.id != mainMetaWindowId) {
        metaWindows[metaWindow.id] = metaWindow;
      }
    }
    final metaWindowIds = metaWindows.keys.toList();

    // Local to the tile: the stack order is presentation state, like a window's
    // position, and does not need to outlive the floating area.
    final zOrder = useState<List<MetaWindowId>>(metaWindowIds);
    final orderKey = metaWindowIds.join('\u0000');
    useEffect(() {
      final present = metaWindowIds.toSet();
      final next = zOrder.value.where(present.contains).toList();
      final mainWasPresent = zOrder.value.contains(mainMetaWindowId);
      for (final metaWindowId in metaWindowIds) {
        if (!next.contains(metaWindowId)) {
          // A dialog that just opened goes on top, matching a floating
          // compositor's raise-on-map.
          next.add(metaWindowId);
        }
      }
      // The displayed window is the tile's base layer. It can appear after the
      // dialogs (e.g. when the launch burst settles) without being raised over
      // them: a full-size window on top would cover the whole stack.
      if (!mainWasPresent && mainMetaWindowId != null) {
        next.remove(mainMetaWindowId);
        next.insert(0, mainMetaWindowId);
      }
      if (!_sameOrder(next, zOrder.value)) {
        zOrder.value = next;
      }
      return null;
    }, [orderKey]);

    // `_NET_WM_STATE_ABOVE` windows stay above the rest regardless of the
    // activation stack: paint the normal windows first, then the keep-on-top
    // ones, each group in its own z-order.
    final orderedMetaWindows = [
      for (final metaWindowId in zOrder.value)
        if (metaWindows[metaWindowId] != null &&
            !metaWindows[metaWindowId]!.keepOnTop)
          metaWindows[metaWindowId]!,
      for (final metaWindowId in zOrder.value)
        if (metaWindows[metaWindowId] != null &&
            metaWindows[metaWindowId]!.keepOnTop)
          metaWindows[metaWindowId]!,
    ];
    final topMetaWindowId = orderedMetaWindows.isEmpty
        ? null
        : orderedMetaWindows.last.id;

    // Popups (menus, X11 override-redirect toolbars) are positioned in output
    // coordinates. Render them in a tile-level overlay rather than inside the
    // parent's `FloatingWindow`: a large popup such as Zoom's meeting toolbar
    // extends well beyond the small annotate palette, and Flutter would paint
    // it (because the parent stack does not clip) while refusing to hit-test it
    // outside the parent's bounds.
    final popupIds = <String>[];
    final popupParents = <String, MetaWindow>{};
    for (final metaWindow in metaWindows.values) {
      for (final popupId in ref.watch(metaPopupForIdProvider(metaWindow.id))) {
        popupIds.add(popupId);
        popupParents[popupId] = metaWindow;
      }
    }

    final monitorName = CurrentMonitorName.of(context);
    final monitorLocation =
        ref.watch(monitorByNameProvider(monitorName))?.location ?? Offset.zero;

    // The floating content area in compositor-global logical coordinates.
    // X11 reports client positions in that same space; the tile itself is
    // offset by the workspace/sidebar, so the raw position must be translated
    // before it is used as a local `Positioned`.
    final contentKey = useMemoized(GlobalKey.new);
    final contentRect = useState<Rect?>(null);
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        final renderBox =
            contentKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) {
          return;
        }
        final origin = renderBox.localToGlobal(Offset.zero) + monitorLocation;
        final next = origin & renderBox.size;
        if (contentRect.value != next) {
          contentRect.value = next;
        }
      });
      return null;
    });

    // Tell the compositor where the floating viewport is so native moves can
    // be clamped to it. Floating ownership itself comes from the routed
    // display mode; this message carries only the measured viewport.
    final contentRectKey = contentRect.value?.toString();
    final decorationKey = metaWindows.values
        .map((window) => '${window.id}:${window.needDecoration}')
        .join('\u0000');
    // Re-publish the viewport when the routed display mode becomes floating or
    // the measured rect changes. Floating ownership lives in `displayMode`;
    // this key only tracks the viewport/provenance state needed to rebuild it.
    final floatingKey = metaWindows.values
        .map(
          (window) =>
              '${window.id}:${window.displayMode}:${window.viewport}:'
              '${window.positionExplicit}',
        )
        .join('\u0000');
    useEffect(() {
      final rect = contentRect.value;
      if (rect == null) {
        return null;
      }
      final windows = metaWindows.values.toList(growable: false);
      // This effect runs during the build phase. Riverpod throws if a provider
      // is modified here, and the unhandled error used to abort the loop before
      // either viewport patch was sent. Publish after the frame instead.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        for (final metaWindow in windows) {
          try {
            final decoration = metaWindow.needDecoration
                ? WindowTitleBar.height
                : 0.0;
            final clientRect = Rect.fromLTWH(
              rect.left,
              rect.top + decoration,
              rect.width,
              math.max(0, rect.height - decoration),
            );
            geometryLog.info(
              'floating viewport id=${metaWindow.id} '
              'rect=$clientRect origin=${rect.topLeft}',
            );
            final notifier = ref.read(
              metaWindowStateProvider(metaWindow.id).notifier,
            );
            unawaited(
              notifier
                  .patch(
                    MetaWindowPatchMessage.updateViewport(
                      id: metaWindow.id,
                      value: clientRect,
                      origin: rect.topLeft,
                    ),
                  )
                  .catchError((Object error, StackTrace stack) {
                    geometryLog.warning(
                      'floating viewport patch failed for ${metaWindow.id}: '
                      '$error\n$stack',
                    );
                  }),
            );
          } catch (error, stack) {
            // A window can be torn down between the build and this post-frame
            // callback; do not let it stop the remaining windows from getting
            // their viewport.
            geometryLog.warning(
              'floating viewport failed for ${metaWindow.id}: '
              '$error\n$stack',
            );
          }
        }
      });
      return null;
    }, [contentRectKey, orderKey, decorationKey, floatingKey]);

    // Selecting the tile hands the keyboard to the window on top, exactly like
    // activating a window in a floating compositor.
    useEffect(() {
      if (!isSelected || topMetaWindowId == null) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        // Keep the tile's focus node in the workspace focus tree so
        // Super+WASD navigation resolves for floating windows too.
        focusNode?.requestFocus();
        _activateMetaWindow(ref, topMetaWindowId);
      });
      return null;
    }, [isSelected, topMetaWindowId, focusNode]);

    void raise(MetaWindowId metaWindowId) {
      final current = zOrder.value;
      final index = current.indexOf(metaWindowId);
      if (index < 0 || index == current.length - 1) {
        return;
      }
      zOrder.value = [...current]
        ..removeAt(index)
        ..add(metaWindowId);
    }

    // The task bar keeps the creation order: raising a window changes the
    // paint stack, not the task-bar entries under the pointer.
    bool isTaskBarWindow(MetaWindow metaWindow) =>
        !metaWindow.skipTaskbar &&
        !metaWindow.isFixedSized &&
        metaWindow.parent == null;
    final taskBarMetaWindows = [
      for (final metaWindowId in metaWindowIds)
        if (metaWindows[metaWindowId] != null &&
            isTaskBarWindow(metaWindows[metaWindowId]!))
          metaWindows[metaWindowId]!,
    ];
    // The CSD maximize button is a client request: the newest window that asked
    // to be maximized fills the tile, and a restore request clears it. Tiled
    // modes keep the tile's own display mode instead.
    MetaWindowId? maximizedMetaWindowId;
    for (final metaWindow in orderedMetaWindows) {
      if (metaWindow.clientMaximized) {
        maximizedMetaWindowId = metaWindow.id;
      }
    }

    Offset? clientOriginFor(MetaWindow metaWindow, Rect? tileRect) {
      final placement = metaWindow.windowPlacement;
      final position = placement?.origin ?? metaWindow.position;
      if (position == null || tileRect == null) {
        return null;
      }
      // The legacy launch configure puts every X11 window at (0,0). If the
      // client has not explicitly placed itself, centre it instead of pinning
      // it to the tile origin. An explicit (0,0) is honoured.
      if (!metaWindow.positionExplicit && position == Offset.zero) {
        return null;
      }
      // `position` is the client surface in compositor-global coordinates;
      // the Flutter box is tile-local and (for a server-decorated window)
      // includes the shell title bar above the client surface.
      final decoration = metaWindow.needDecoration
          ? WindowTitleBar.height
          : 0.0;
      return position - tileRect.topLeft - Offset(0, decoration);
    }

    final floatingChildren = <Widget>[];
    for (final metaWindow in orderedMetaWindows) {
      floatingChildren.add(
        FloatableWindow(
          // The key keeps each window's state (position, size, surface) with
          // the window when the stack is reordered.
          key: ValueKey(metaWindow.id),
          metaWindowId: metaWindow.id,
          placement: FloatableWindowPlacement.floatingTile,
          tileGlobalOrigin: contentRect.value?.topLeft,
          clientOrigin: clientOriginFor(metaWindow, contentRect.value),
          maximized: metaWindow.id == maximizedMetaWindowId,
          // Popups live in the tile-level overlay below so they can receive
          // input outside this window's box.
          showPopups: false,
          allowResize: true,
          // Client-decorated windows (the Zoom panels) keep their own frame and
          // shadow; the shell only draws decoration when the client asked for
          // it.
          frame: true,
          onRaise: () {
            focusNode?.requestFocus();
            raise(metaWindow.id);
            _activateMetaWindow(ref, metaWindow.id);
          },
        ),
      );
    }

    final content = Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                key: contentKey,
                fit: StackFit.expand,
                children: [
                  background,
                  if (floatingChildren.isNotEmpty)
                    ContainerWithPositionnableChildren(
                      children: floatingChildren,
                    ),
                  if (popupIds.isNotEmpty)
                    Positioned.fill(
                      // Same pointer contract as a surface and its popups: the
                      // deferred handler must be an ancestor of the popup's
                      // input listener for clicks to reach the popup surface.
                      //
                      // Popups live in output/root coordinates. This overlay
                      // fills the measured content area, so its origin is the
                      // tile content origin and it follows the tile when the
                      // workspace moves — no separately cached offset.
                      child: DeferredPointerHandler(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final popupId in popupIds)
                              MetaPopupWidget(
                                metaPopupId: popupId,
                                parentOrigin:
                                    popupParents[popupId]
                                        ?.windowPlacement
                                        ?.origin ??
                                    popupParents[popupId]?.position ??
                                    Offset.zero,
                                coordinateOffset:
                                    contentRect.value?.topLeft ?? Offset.zero,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _FloatingTaskBar(
              metaWindows: taskBarMetaWindows,
              topMetaWindowId: topMetaWindowId,
              onSelect: (metaWindowId) {
                focusNode?.requestFocus();
                raise(metaWindowId);
                _activateMetaWindow(ref, metaWindowId);
              },
            ),
          ],
        ),
        if (chooser != null) FileChooserModal(request: chooser),
      ],
    );

    final node = focusNode;
    return node == null ? content : Focus(focusNode: node, child: content);
  }
}

/// The floating tile's task bar: one entry per window in the stack.
///
/// It lives inside the tile (floating mode only), so Zoom's panels are
/// reachable even when they are covered by another floating window.
class _FloatingTaskBar extends StatelessWidget {
  const _FloatingTaskBar({
    required this.metaWindows,
    required this.topMetaWindowId,
    required this.onSelect,
  });

  /// Bottom-to-top stack order; the bar lists them in the same order.
  final List<MetaWindow> metaWindows;
  final MetaWindowId? topMetaWindowId;
  final ValueChanged<MetaWindowId> onSelect;

  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    if (metaWindows.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SizedBox(
        height: height,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          children: [
            for (final metaWindow in metaWindows)
              _FloatingTaskBarItem(
                metaWindow: metaWindow,
                isTop: metaWindow.id == topMetaWindowId,
                onTap: () => onSelect(metaWindow.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingTaskBarItem extends StatelessWidget {
  const _FloatingTaskBarItem({
    required this.metaWindow,
    required this.isTop,
    required this.onTap,
  });

  final MetaWindow metaWindow;
  final bool isTop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('floating-taskbar-${metaWindow.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isTop
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: AppIconById(id: metaWindow.appId),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    metaWindow.title ?? context.l10n.unknown,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether two window-id lists hold the same order.
bool _sameOrder(List<MetaWindowId> a, List<MetaWindowId> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

/// Asks the compositor to activate [metaWindowId], raising it natively (X11)
/// and handing it the keyboard.
void _activateMetaWindow(WidgetRef ref, MetaWindowId metaWindowId) {
  final metaWindow = _readMetaWindow(ref, metaWindowId);
  if (metaWindow == null) {
    return;
  }
  unawaited(
    ref
        .read(platformManagerProvider.notifier)
        .request(
          ActivateWindowRequest(
            message: ActivateWindowMessage(
              surfaceId: metaWindow.surfaceId,
              activate: true,
            ),
          ),
        ),
  );
}

/// A dialog's meta window, or `null` when the dialog is not tracked yet or its
/// meta window is already gone. Both providers throw by design until their
/// state exists, which is why this is read defensively.
MetaWindow? _readDialogMetaWindow(
  WidgetRef ref,
  DialogWindowId dialogWindowId,
) {
  try {
    final metaWindowId = ref
        .watch(dialogWindowStateProvider(dialogWindowId))
        .metaWindowId;
    return ref.watch(metaWindowStateProvider(metaWindowId));
  } on Object {
    return null;
  }
}

/// Watches a meta window, or returns `null` when it is gone.
MetaWindow? _watchMetaWindow(WidgetRef ref, MetaWindowId metaWindowId) {
  try {
    return ref.watch(metaWindowStateProvider(metaWindowId));
  } on Object {
    return null;
  }
}

/// Reads a meta window, or `null` when it is gone.
MetaWindow? _readMetaWindow(WidgetRef ref, MetaWindowId metaWindowId) {
  try {
    return ref.read(metaWindowStateProvider(metaWindowId));
  } on Object {
    return null;
  }
}
