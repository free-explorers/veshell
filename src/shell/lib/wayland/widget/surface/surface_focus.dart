import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SurfaceFocus extends HookConsumerWidget {
  const SurfaceFocus({required this.child, this.focusNode, super.key});
  final FocusNode? focusNode;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      // https://github.com/flutter/flutter/blob/73e78fd97c44a88fc164b683e8779293ebe85e95/packages/flutter/lib/src/widgets/app.dart#L1234

      shortcuts: {
        // Activation.
        //
        // The bare keys use `LogicalKeySet` (an exact chord) rather than
        // `SingleActivator`: the latter only checks control/shift/alt/meta, so
        // it also matches while the Super key is held. That would swallow a
        // `Super+Arrow` (or `Super+Space`) chord here — closer to focus than
        // the shell's shortcut manager — and forward it to the client instead
        // of letting the shell navigate. `LogicalKeySet({key})` only matches
        // the key on its own, so Super-modified chords pass through.
        LogicalKeySet.fromSet({LogicalKeyboardKey.enter}):
            DisableDefaultShortcutsIntent(),
        LogicalKeySet.fromSet({LogicalKeyboardKey.numpadEnter}):
            DisableDefaultShortcutsIntent(),
        LogicalKeySet.fromSet({LogicalKeyboardKey.space}):
            DisableDefaultShortcutsIntent(),
        LogicalKeySet.fromSet({LogicalKeyboardKey.gameButtonA}):
            DisableDefaultShortcutsIntent(),
        LogicalKeySet.fromSet({LogicalKeyboardKey.select}):
            DisableDefaultShortcutsIntent(),

        // Dismissal
        LogicalKeySet.fromSet({LogicalKeyboardKey.escape}):
            DisableDefaultShortcutsIntent(),

        // Keyboard traversal.
        LogicalKeySet.fromSet({LogicalKeyboardKey.tab}):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true):
            DisableDefaultShortcutsIntent(),
        LogicalKeySet.fromSet({LogicalKeyboardKey.arrowLeft}):
            DisableDefaultShortcutsIntent(),
        LogicalKeySet.fromSet({LogicalKeyboardKey.arrowRight}):
            DisableDefaultShortcutsIntent(),
        LogicalKeySet.fromSet({LogicalKeyboardKey.arrowDown}):
            DisableDefaultShortcutsIntent(),
        LogicalKeySet.fromSet({LogicalKeyboardKey.arrowUp}):
            DisableDefaultShortcutsIntent(),

        // Scrolling
        const SingleActivator(LogicalKeyboardKey.arrowUp, control: true):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.pageUp):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.pageDown):
            DisableDefaultShortcutsIntent(),
      },
      child: Actions(
        actions: {
          DisableDefaultShortcutsIntent: DisableDefaultShortcutsAction(),
        },
        child: Focus(focusNode: focusNode, child: child),
      ),
    );
  }
}

class DisableDefaultShortcutsIntent extends Intent {}

class DisableDefaultShortcutsAction
    extends Action<DisableDefaultShortcutsIntent> {
  @override
  Object? invoke(DisableDefaultShortcutsIntent intent) => null;

  /// The embedder will only send key events to Wayland clients if they are not handled by Flutter.
  @override
  bool consumesKey(DisableDefaultShortcutsIntent intent) => false;
}
