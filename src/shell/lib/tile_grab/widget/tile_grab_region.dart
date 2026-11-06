import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
///
/// While Super is held the whole tile shows the grab cursor, over client
/// surfaces and shell controls alike, since a press there grabs the tile.
class TileGrabRegion extends HookConsumerWidget {
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
    final superPressed = _useSuperKeyPressed();
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
      // The cursor layer is on top so it wins over the tile's own controls
      // (a close button would otherwise show its click cursor), and it is
      // translucent so it never takes hits away from them. It stays in the
      // tree with a deferring cursor so toggling Super does not rebuild the
      // tile.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: MouseRegion(
              // The default (opaque) would end the hit test here and starve
              // the tile below of every pointer event.
              opaque: false,
              cursor: superPressed
                  ? SystemMouseCursors.grab
                  : MouseCursor.defer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tracks whether Super is held, rebuilding when it changes.
bool _useSuperKeyPressed() {
  final pressed = useState(isSuperKeyPressed());
  useEffect(() {
    bool handler(KeyEvent event) {
      // Read after the keyboard state applied the event, so a press and its
      // release are both reflected.
      final next = isSuperKeyPressed();
      if (next != pressed.value) pressed.value = next;
      return false;
    }

    HardwareKeyboard.instance.addHandler(handler);
    return () => HardwareKeyboard.instance.removeHandler(handler);
  }, const []);
  return pressed.value;
}

class _GrabArenaMember implements GestureArenaMember {
  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {}
}
