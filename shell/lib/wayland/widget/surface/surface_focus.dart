import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/util/logger.dart';

class SurfaceFocus extends HookConsumerWidget {
  const SurfaceFocus({
    required this.child,
    this.focusNode,
    super.key,
  });
  final FocusNode? focusNode;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      // https://github.com/flutter/flutter/blob/73e78fd97c44a88fc164b683e8779293ebe85e95/packages/flutter/lib/src/widgets/app.dart#L1234

      shortcuts: {
        // Activation
        const SingleActivator(LogicalKeyboardKey.enter):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.space):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.select):
            DisableDefaultShortcutsIntent(),

        // Dismissal
        const SingleActivator(LogicalKeyboardKey.escape):
            DisableDefaultShortcutsIntent(),

        // Keyboard traversal.
        const SingleActivator(LogicalKeyboardKey.tab):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            DisableDefaultShortcutsIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp):
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
        child: Focus(
          focusNode: focusNode,
          onFocusChange: (value) {
            print('Surface focus $value');
          },
          child: Listener(
            onPointerDown: (_) {
              focusNode?.requestFocus();
              focusLog.info('SurfaceFocus.requestFocus on PinterDown');
            },
            child: child,
          ),
        ),
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
