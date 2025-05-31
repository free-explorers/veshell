import 'package:arena_listener/arena_listener.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/platform/model/request/mouse_buttons_event/mouse_buttons_event.serializable.dart';
import 'package:shell/platform/model/request/touch/touch.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/pointer/model/pointer_focus.serializable.dart';
import 'package:shell/pointer/provider/pointer_focus.manager.dart';
import 'package:shell/shared/provider/mouse_button_tracker.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

/// Handles all input events for a given window or popup, and redirects them to the platform which will then be
/// forwarded to the appropriate surface.
class ViewInputListener extends HookConsumerWidget {
  const ViewInputListener({
    required this.surfaceId,
    required this.child,
    super.key,
  });

  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointerFocusManager = ref.read(pointerFocusManagerProvider.notifier);

    final inputRegion = ref
        .watch(wlSurfaceStateProvider(surfaceId).select((v) => v.inputRegion));

    final globalKey = useMemoized(GlobalKey.new);
    return DeferPointer(
      child: Stack(
        key: globalKey,
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            child: child,
          ),
          Positioned.fromRect(
            rect: inputRegion,
            child: ArenaListener(
              onPointerDown: (PointerDownEvent event) {
                final renderBox =
                    globalKey.currentContext!.findRenderObject() as RenderBox?;
                final globalOffset =
                    renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
                _onPointerDown(ref, event, globalOffset);
                return null;
              },
              onPointerMove:
                  (PointerMoveEvent event, GestureDisposition? disposition) {
                if (disposition == GestureDisposition.rejected) {
                  return;
                }
                final renderBox =
                    globalKey.currentContext!.findRenderObject() as RenderBox?;
                final globalOffset =
                    renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
                _onPointerMove(ref, event, globalOffset);
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
                    final renderBox = globalKey.currentContext!
                        .findRenderObject() as RenderBox?;
                    final globalOffset =
                        renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

                    _pointerMoved(ref, globalOffset);
                  }
                },
                onPointerSignal: (PointerSignalEvent event) {
                  // https://api.flutter.dev/flutter/gestures/PointerSignalResolver-class.html
                  // Don't propagate scroll events to parent widgets.
                  // Just register an empty handler because dispatching of
                  // scroll events is handled by the Wayland server.
                  GestureBinding.instance.pointerSignalResolver.register(
                    event,
                    (PointerSignalEvent event) {},
                  );
                },
                child: MouseRegion(
                  onEnter: (_) {
                    final renderBox = globalKey.currentContext!
                        .findRenderObject() as RenderBox?;
                    final globalOffset =
                        renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

                    pointerFocusManager.enterSurface(
                      PointerFocus(
                        surfaceId: surfaceId,
                        globalOffset: globalOffset,
                      ),
                    );
                  },
                  onExit: (_) => pointerFocusManager.exitSurface(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onPointerDown(
    WidgetRef ref,
    PointerEvent event,
    Offset globalOffset,
  ) async {
    if (event.kind == PointerDeviceKind.mouse) {
      await _sendMouseButtonsToPlatform(ref, event.buttons);
      ref.read(pointerFocusManagerProvider.notifier).startPotentialDrag();
    } else if (event.kind == PointerDeviceKind.touch) {
      await ref.read(platformManagerProvider.notifier).request(
            TouchDownRequest(
              message: TouchDownMessage(
                surfaceId: surfaceId,
                touchId: event.pointer,
              ),
            ),
          );
    }
  }

  Future<void> _onPointerMove(
    WidgetRef ref,
    PointerEvent event,
    Offset globalOffset,
  ) async {
    if (event.kind == PointerDeviceKind.mouse) {
      // If a button is being pressed while another one is already down,
      // it's considered a move event, not a down event.
      await _sendMouseButtonsToPlatform(ref, event.buttons);
      _pointerMoved(ref, globalOffset);
    } else if (event.kind == PointerDeviceKind.touch) {
      await ref.read(platformManagerProvider.notifier).request(
            TouchMotionRequest(
              message: TouchMotionMessage(
                touchId: event.pointer,
              ),
            ),
          );
    }
  }

  Future<void> _onPointerUp(WidgetRef ref, PointerUpEvent event) async {
    if (event.kind == PointerDeviceKind.mouse) {
      await _sendMouseButtonsToPlatform(ref, event.buttons);
      ref.read(pointerFocusManagerProvider.notifier).stopPotentialDrag();
    } else if (event.kind == PointerDeviceKind.touch) {
      await ref.read(platformManagerProvider.notifier).request(
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
      ref.read(pointerFocusManagerProvider.notifier).stopPotentialDrag();
    } else if (lastPointerEvent.kind == PointerDeviceKind.touch) {
      await ref.read(platformManagerProvider.notifier).request(
            TouchCancelRequest(
              message: TouchIdMessage(touchId: lastPointerEvent.pointer),
            ),
          );
    }
  }

  Future<void> _sendMouseButtonsToPlatform(WidgetRef ref, int buttons) async {
    final events =
        ref.read(mouseButtonTrackerProvider).trackButtonState(buttons);

    if (events.isNotEmpty) {
      await _mouseButtonsEvent(ref, events);
    }
  }

  Future<void> _mouseButtonsEvent(
    WidgetRef ref,
    List<MouseButtonEvent> events,
  ) {
    return ref.read(platformManagerProvider.notifier).request(
          MouseButtonsEventRequest(
            message: MouseButtonsEventMessage(
              surfaceId: surfaceId,
              buttons: events
                  .map(
                    (e) => Button(
                      button: e.button,
                      isPressed: e.state == MouseButtonState.pressed,
                    ),
                  )
                  .toList()
                  .lockUnsafe,
            ),
          ),
        );
  }

  void _pointerMoved(WidgetRef ref, Offset globalOffset) {
    return ref.read(pointerFocusManagerProvider.notifier).hoverSurface(
          PointerFocus(surfaceId: surfaceId, globalOffset: globalOffset),
        );
  }
}
