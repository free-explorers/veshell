import 'package:flutter/gestures.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/provider/meta_window_dragging_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

class MetaSurfaceDecoration extends HookConsumerWidget {
  const MetaSurfaceDecoration({
    required this.metaWindowId,
    required this.enabled,
    required this.child,
    this.onTitleBarMoveStart,
    super.key,
  });
  final bool enabled;
  final Widget child;
  final String metaWindowId;

  /// Primary-button press on the shell-drawn title bar. `null` keeps the
  /// historical local drag used by the dialog area and the maximized tile.
  final VoidCallback? onTitleBarMoveStart;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaWindow = ref.watch(metaWindowStateProvider(metaWindowId));

    final surfaceSize = ref.watch(
      wlSurfaceStateProvider(
        metaWindow.surfaceId,
      ).select((v) => v.texture!.size),
    );

    var height = metaWindow.geometry?.height ?? surfaceSize.height;
    if (metaWindow.geometry?.height != null) {
      height =
          metaWindow.geometry!.height +
          (metaWindow.needDecoration ? WindowTitleBar.height : 0);
    }
    if (!enabled) {
      return child;
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: windowFrameDecoration,
      width: metaWindow.geometry?.width ?? surfaceSize.width,
      height: height,
      child: Column(
        children: [
          WindowTitleBar(metaWindowId, onMoveStart: onTitleBarMoveStart),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// The shell's window frame: a rounded, clipped box with a drop shadow.
///
/// Used by [MetaSurfaceDecoration] for server-side decoration, title bar
/// included, so every shell-drawn window edge reads the same.
const windowFrameDecoration = BoxDecoration(
  borderRadius: BorderRadius.all(Radius.circular(10)),
  boxShadow: [
    BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 5),
  ],
);

/// A bare shell frame for a floating dialog: rounded corners and a drop shadow,
/// without the title bar [MetaSurfaceDecoration] adds for a client that asked
/// for server-side decoration.
///
/// A client-declared dialog in the tile's dialog overlay floats over the dimmed
/// tile. A client that draws no decoration of its own would otherwise read as a
/// flat rectangle pasted on the dim. It is only drawn around a bare surface: a
/// client that carries its own decoration in its surface buffer keeps it.
class ServerSideFrame extends StatelessWidget {
  const ServerSideFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: windowFrameDecoration,
      child: child,
    );
  }
}

class WindowTitleBar extends HookConsumerWidget {
  const WindowTitleBar(this.metaWindowId, {this.onMoveStart, super.key});
  final String metaWindowId;

  /// Primary-button press on the title bar. When set, the caller owns the move
  /// (the floating tile asks the compositor); when `null`, the historical
  /// `MetaWindowDraggingState` local drag is used.
  final VoidCallback? onMoveStart;

  /// Height of the shell-drawn title bar added above a decorated surface.
  static const double height = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaWindow = ref.watch(metaWindowStateProvider(metaWindowId));
    return Listener(
      behavior: HitTestBehavior.translucent,
      // Start on pointer down, not on pan start: the first pan move is what
      // triggers `onPanStart`, and by then that move's delta would already be
      // lost, making the window lag the pointer for the rest of the drag.
      onPointerDown: (event) {
        final moveStart = onMoveStart;
        if (moveStart != null) {
          // Floating tile: the compositor owns the move. Restrict it to the
          // primary button so a close-button or secondary click is unaffected.
          if (event.buttons == kPrimaryButton) {
            geometryLog.info('title-bar move start id=$metaWindowId');
            moveStart();
          }
          return;
        }
        // Dialog-area overlay: keep the historical local drag.
        ref
            .read(metaWindowDraggingStateProvider(metaWindow.id).notifier)
            .startDragging();
      },
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: SizedBox(
          height: WindowTitleBar.height,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Text(
                metaWindow.title ?? '',
                style: const TextStyle(color: Colors.white),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  ref
                      .read(metaWindowStateProvider(metaWindowId).notifier)
                      .requestToClose();
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
