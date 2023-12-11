import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/tasks/tasks.provider.dart';
import 'package:shell/manager/surface/xdg_toplevel/xdg_toplevel.provider.dart';

class ActivateAndRaise extends ConsumerWidget {
  const ActivateAndRaise({
    required this.surfaceId,
    required this.child,
    super.key,
  });
  final int surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Listener(
      onPointerDown: (_) {
        ref.read(xdgToplevelStatesProvider(surfaceId)).focusNode.requestFocus();
        ref.read(tasksProvider.notifier).putInFront(surfaceId);
      },
      child: child,
    );
  }
}
