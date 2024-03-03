import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SurfaceFocus extends HookConsumerWidget {
  const SurfaceFocus({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusNode = useFocusNode(debugLabel: 'SurfaceFocus');

    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.tab):
        DisableFocusTraversalIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true):
        DisableFocusTraversalIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
        DisableFocusTraversalIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
        DisableFocusTraversalIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
        DisableFocusTraversalIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp):
        DisableFocusTraversalIntent(),
      },
      child: Actions(
        actions: {
          DisableFocusTraversalIntent: DisableFocusTraversalAction(),
        },
        child: Focus(
          focusNode: focusNode,
          child: child,
        ),
      ),
    );
  }
}

class DisableFocusTraversalIntent extends Intent {}

class DisableFocusTraversalAction extends Action<DisableFocusTraversalIntent> {
  @override
  Object? invoke(DisableFocusTraversalIntent intent) => null;

  /// The embedder will only send key events to Wayland clients if they are not handled by Flutter.
  @override
  bool consumesKey(DisableFocusTraversalIntent intent) => false;
}
