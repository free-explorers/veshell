import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

class ActivateSurfaceOnPointerDown extends ConsumerWidget {
  const ActivateSurfaceOnPointerDown({required this.surfaceId, required this.child, super.key,
    this.enabled = true,
  });

  final SurfaceId surfaceId;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) {
      return child;
    }

    return Listener(
      onPointerDown: (_) => ref.read(waylandManagerProvider.notifier).request(
            ActivateWindowRequest(
              message: ActivateWindowMessage(
                surfaceId: surfaceId,
                activate: true,
              ),
            ),
          ),
      child: child,
    );
  }
}
