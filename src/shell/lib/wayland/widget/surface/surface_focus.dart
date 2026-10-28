import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shortcut_manager/model/super_key.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';

/// Keys a focused client surface owns even when the shell binds them.
///
/// A client still expects Enter, Space, Escape and the navigation keys to reach
/// it; passing them through is what keeps a focused application usable.
final _clientOwnedKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.gameButtonA,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.escape,
  LogicalKeyboardKey.tab,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.pageDown,
};

/// Routes keyboard input between a focused Wayland client and the shell.
///
/// The embedder only hands a key to the client when Flutter does not handle it.
/// A configured shell hotkey therefore wins over the client, while every other
/// key is left unhandled so the client receives it. The shell hotkeys come from
/// the user's settings, so a custom chord such as `Ctrl+Super+Arrow` is not
/// swallowed by a built-in pass-through. Super chords also stay with the shell
/// because the overview binds some of them locally rather than through the
/// hotkey settings.
class SurfaceFocus extends HookConsumerWidget {
  const SurfaceFocus({required this.child, this.focusNode, super.key});
  final FocusNode? focusNode;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellShortcuts = ref.watch(hotkeysActivatorProvider);

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        // A shell control inside the surface (for example a decoration button)
        // owns the keyboard; leave its events to the Flutter focus tree.
        if (!node.hasPrimaryFocus) {
          return KeyEventResult.ignored;
        }
        // Releases must reach the shell: it toggles the overview when Super is
        // released on its own.
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        final keyboard = HardwareKeyboard.instance;
        final superPressed = isSuperKeyPressed(keyboard);
        final hasModifier =
            keyboard.isControlPressed ||
            keyboard.isShiftPressed ||
            keyboard.isAltPressed ||
            superPressed;

        // Plain keys that a client always expects, even when configured as a
        // shell action (`navigation.activate` is Enter by default).
        if (!hasModifier && _clientOwnedKeys.contains(event.logicalKey)) {
          return KeyEventResult.skipRemainingHandlers;
        }

        final isShellChord =
            superPressed ||
            shellShortcuts.keys.any(
              (activator) => activator.accepts(event, keyboard),
            );
        return isShellChord
            ? KeyEventResult.ignored
            : KeyEventResult.skipRemainingHandlers;
      },
      child: child,
    );
  }
}
