import 'package:arena_listener/arena_listener.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/pointer/pointer_focus.manager.dart';
import 'package:shell/manager/wayland/request/mouse_button_event/mouse_button_event.model.serializable.dart';
import 'package:shell/manager/wayland/request/pointer_hover/pointer_hover.model.serializable.dart';
import 'package:shell/manager/wayland/request/touch/touch.model.serializable.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.provider.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';
import 'package:shell/shared/util/mouse_button_tracker.provider.dart';

/// Handles all input events for a given window or popup, and redirects them to the platform which will then be
/// forwarded to the appropriate surface.
class ViewInputListener extends ConsumerWidget {
  const ViewInputListener({
    required this.surfaceId,
    required this.child,
    super.key,
  });
  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointerFocusManager = ref.read(pointerFocusManagerProvider);

    final inputRegion = ref
        .watch(wlSurfaceStateProvider(surfaceId).select((v) => v.inputRegion));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: child,
        ),
        Positioned.fromRect(
          rect: inputRegion,
          child: ArenaListener(
            onPointerDown: (PointerDownEvent event) {
              _onPointerDown(ref, event, inputRegion.topLeft);
              return null;
            },
            onPointerMove:
                (PointerMoveEvent event, GestureDisposition? disposition) {
              if (disposition == GestureDisposition.rejected) {
                return;
              }
              _onPointerMove(ref, event, inputRegion.topLeft);
              return null;
            },
            onPointerUp:
                (PointerUpEvent event, GestureDisposition? disposition) {
              if (disposition == GestureDisposition.rejected) {
                return null;
              }
              _onPointerUp(ref, event);
              return GestureDisposition.accepted;
            },
            onPointerCancel: (_, __) {
              return GestureDisposition.rejected;
            },
            onLose: (event) => _onLoseArena(ref, event),
            child: Listener(
              onPointerHover: (PointerHoverEvent event) {
                if (event.kind == PointerDeviceKind.mouse) {
                  final position = event.localPosition + inputRegion.topLeft;
                  _pointerMoved(ref, position);
                }
              },
              child: MouseRegion(
                onEnter: (_) => pointerFocusManager.enterSurface(),
                onExit: (_) => pointerFocusManager.exitSurface(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onPointerDown(
    WidgetRef ref,
    PointerEvent event,
    Offset inputRegionTopLeft,
  ) async {
    final position = event.localPosition + inputRegionTopLeft;

    if (event.kind == PointerDeviceKind.mouse) {
      await _pointerMoved(ref, position);
      await _sendMouseButtonsToPlatform(ref, event.buttons);
      ref.read(pointerFocusManagerProvider).startPotentialDrag();
    } else if (event.kind == PointerDeviceKind.touch) {
      await ref.read(waylandManagerProvider.notifier).request(
            TouchDownRequest(
              message: TouchDownMessage(
                surfaceId: surfaceId,
                touchId: event.pointer,
                x: position.dx,
                y: position.dy,
              ),
            ),
          );
    }
  }

  Future<void> _onPointerMove(
    WidgetRef ref,
    PointerEvent event,
    Offset inputRegionTopLeft,
  ) async {
    final position = event.localPosition + inputRegionTopLeft;

    if (event.kind == PointerDeviceKind.mouse) {
      // If a button is being pressed while another one is already down,
      // it's considered a move event, not a down event.
      await _sendMouseButtonsToPlatform(ref, event.buttons);
      await _pointerMoved(ref, position);
    } else if (event.kind == PointerDeviceKind.touch) {
      await ref.read(waylandManagerProvider.notifier).request(
            TouchMotionRequest(
              message: TouchMotionMessage(
                touchId: event.pointer,
                x: position.dx,
                y: position.dy,
              ),
            ),
          );
    }
  }

  Future<void> _onPointerUp(WidgetRef ref, PointerUpEvent event) async {
    if (event.kind == PointerDeviceKind.mouse) {
      await _sendMouseButtonsToPlatform(ref, event.buttons);
      ref.read(pointerFocusManagerProvider).stopPotentialDrag();
    } else if (event.kind == PointerDeviceKind.touch) {
      await ref.read(waylandManagerProvider.notifier).request(
            TouchUpRequest(message: TouchIdMessage(touchId: event.pointer)),
          );
    }
  }

  Future<void> _onLoseArena(
    WidgetRef ref,
    PointerEvent lastPointerEvent,
  ) async {
    if (lastPointerEvent.kind == PointerDeviceKind.mouse) {
      await _sendMouseButtonsToPlatform(ref, 0);
      ref.read(pointerFocusManagerProvider).stopPotentialDrag();
    } else if (lastPointerEvent.kind == PointerDeviceKind.touch) {
      await ref.read(waylandManagerProvider.notifier).request(
            TouchCancelRequest(
              message: TouchIdMessage(touchId: lastPointerEvent.pointer),
            ),
          );
    }
  }

  Future<void> _sendMouseButtonsToPlatform(WidgetRef ref, int buttons) async {
    final e = ref.read(mouseButtonTrackerProvider).trackButtonState(buttons);
    if (e != null) {
      await _mouseButtonEvent(ref, e);
    }
  }

  Future<void> _mouseButtonEvent(WidgetRef ref, MouseButtonEvent event) {
    return ref.read(waylandManagerProvider.notifier).request(
          MouseButtonEventRequest(
            message: MouseButtonEventMessage(
              button: event.button,
              isPressed: event.state == MouseButtonState.pressed,
            ),
          ),
        );
  }

  Future<void> _pointerMoved(WidgetRef ref, Offset position) {
    return ref.read(waylandManagerProvider.notifier).request(
          PointerHoverRequest(
            message: PointerHoverMessage(
              surfaceId: surfaceId,
              x: position.dx,
              y: position.dy,
            ),
          ),
        );
  }
}
