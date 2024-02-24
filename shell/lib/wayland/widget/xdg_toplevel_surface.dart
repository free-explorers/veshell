import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/wayland/provider/xdg_surface_state.dart';
import 'package:shell/wayland/widget/surface.dart';
import 'package:shell/wayland/widget/surface/xdg_popup/popup.dart';
import 'package:visibility_detector/visibility_detector.dart';

class XdgToplevelSurfaceWidget extends ConsumerWidget {
  const XdgToplevelSurfaceWidget({
    required this.surfaceId,
    super.key,
  });

  final SurfaceId surfaceId;

  void _collectPopupList(List<int> ids, WidgetRef ref, SurfaceId surfaceId) {
    final popups = ref.watch(
        xdgSurfaceStateProvider(surfaceId).select((value) => value.popups));
    ids.addAll(popups);
    for (final popupId in popups) {
      _collectPopupList(ids, ref, popupId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popupList = <int>[];
    _collectPopupList(popupList, ref, surfaceId);

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
