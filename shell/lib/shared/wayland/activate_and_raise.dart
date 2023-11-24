import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/tasks/tasks.provider.dart';
import 'package:shell/shared/wayland/xdg_toplevel/xdg_toplevel.provider.dart';

class ActivateAndRaise extends ConsumerWidget {
  const ActivateAndRaise({
    required this.viewId,
    required this.child,
    super.key,
  });
  final int viewId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Listener(
      onPointerDown: (_) {
        ref.read(xdgToplevelStatesProvider(viewId)).focusNode.requestFocus();
        ref.read(tasksProvider.notifier).putInFront(viewId);
      },
      child: child,
    );
  }
}
