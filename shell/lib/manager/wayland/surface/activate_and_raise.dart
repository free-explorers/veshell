import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/wayland/request/activate_window/activate_window.model.serializable.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';
import 'package:shell/shared/tasks/tasks.provider.dart';

class ActivateAndRaise extends ConsumerWidget {
  const ActivateAndRaise({
    required this.surfaceId,
    required this.child,
    super.key,
  });
  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Listener(
      onPointerDown: (_) {
        ref.read(waylandManagerProvider.notifier).request(
              ActivateWindowRequest(
                message: ActivateWindowMessage(
                  surfaceId: surfaceId,
                  activate: true,
                ),
              ),
            );
        ref.read(tasksProvider.notifier).putInFront(surfaceId);
      },
      child: child,
    );
  }
}
