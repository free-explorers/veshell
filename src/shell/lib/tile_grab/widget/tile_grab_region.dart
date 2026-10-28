import 'package:flutter/gestures.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/widget/multi_view_drag.dart';
import 'package:shell/shortcut_manager/model/super_key.dart';
import 'package:shell/tile_grab/provider/tile_grab_controller.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/widget/current_workspace_id.dart';

/// Lets `Super` + primary-button drag anywhere on a tile hold the whole tile.
///
/// The press belongs to the shell: it wins the gesture arena, so no shell
/// control inside the tile reacts to it, and client surfaces do not forward it
/// (see [TileGrabRegion.claims]).
class TileGrabRegion extends ConsumerWidget {
  const TileGrabRegion({
    required this.windowId,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final PersistentWindowId windowId;

  /// A disabled region lets Super-presses through (a game tile owns them).
  final bool enabled;
  final Widget child;

  /// Whether a pointer-down inside [context] will start a tile grab.
  ///
  /// Descendants acting on a raw pointer-down (client surfaces, title bars)
  /// see the press before the region does, so they check this to leave it to
  /// the grab instead of forwarding it to the client.
  static bool claims(BuildContext context, PointerDownEvent event) =>
      _isGrabPress(event) &&
      (context.findAncestorWidgetOfExactType<TileGrabRegion>()?.enabled ??
          false);

  static bool _isGrabPress(PointerDownEvent event) =>
      event.kind == PointerDeviceKind.mouse &&
      event.buttons == kPrimaryButton &&
      isSuperKeyPressed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return child;
    final workspaceId = CurrentWorkspaceId.of(context);
    final screenId = CurrentScreenId.of(context);
    return Listener(
      onPointerDown: (event) {
        if (!_isGrabPress(event)) return;
        final source = ShellDragSource.of(context);
        final box = context.findRenderObject() as RenderBox?;
        if (source == null || box == null) return;
        // Win the arena outright so buttons, title bars and swipes inside the
        // tile all lose this press.
        GestureBinding.instance.gestureArena
            .add(event.pointer, _GrabArenaMember())
            .resolve(GestureDisposition.accepted);
        ref
            .read(tileGrabControllerProvider.notifier)
            .start(
              source: source,
              event: event,
              windowId: windowId,
              workspaceId: workspaceId,
              screenId: screenId,
              tileRect: box.localToGlobal(Offset.zero) & box.size,
            );
      },
      child: child,
    );
  }
}

class _GrabArenaMember implements GestureArenaMember {
  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {}
}
