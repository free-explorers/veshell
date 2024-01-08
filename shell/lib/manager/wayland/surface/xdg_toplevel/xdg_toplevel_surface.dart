import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/wayland/request/activate_window/activate_window.model.serializable.dart';
import 'package:shell/manager/wayland/surface/surface.manager.dart';
import 'package:shell/manager/wayland/surface/wl_surface/surface.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/surface/xdg_popup/popup.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

class XdgToplevelSurfaceWidget extends ConsumerWidget {
  const XdgToplevelSurfaceWidget({
    required this.surfaceId,
    super.key,
  });
  final SurfaceId surfaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popupList = ref.watch(
      popupListForSurfaceProvider.select((value) => value.get(surfaceId)),
    );
    return VisibilityDetector(
      key: ValueKey(surfaceId),
      onVisibilityChanged: (VisibilityInfo info) {
        final visible = info.visibleFraction > 0;
        if (ref.context.mounted) {
          /* ref.read(xdgToplevelStateProvider(surfaceId).notifier).visible =
              visible; */
        }
      },
      child: _SurfaceFocus(
        surfaceId: surfaceId,
        child: Stack(
          children: [
            _PointerListener(
              surfaceId: surfaceId,
              child: SurfaceWidget(
                surfaceId: surfaceId,
              ),
            ),
            for (final popupSurfaceId in popupList)
              PopupWidget(surfaceId: popupSurfaceId),
          ],
        ),
      ),
    );
  }
}

class _SurfaceFocus extends HookConsumerWidget {
  const _SurfaceFocus({
    required this.surfaceId,
    required this.child,
  });
  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusNode = useFocusNode();
    useEffect(
      () {
        focusNode.addListener(() {
          ref.read(waylandManagerProvider.notifier).request(
                ActivateWindowRequest(
                  message: ActivateWindowMessage(
                    surfaceId: surfaceId,
                    activate: focusNode.hasFocus,
                  ),
                ),
              );
        });
        return null;
      },
      [focusNode],
    );

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

class _PointerListener extends ConsumerWidget {
  const _PointerListener({
    required this.surfaceId,
    required this.child,
  });
  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class DisableFocusTraversalIntent extends Intent {}

class DisableFocusTraversalAction extends Action<DisableFocusTraversalIntent> {
  @override
  Object? invoke(DisableFocusTraversalIntent intent) => null;

  /// The embedder will only send key events to Wayland clients if they are not handled by Flutter.
  @override
  bool consumesKey(DisableFocusTraversalIntent intent) => false;
}
