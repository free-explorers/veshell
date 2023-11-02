import 'package:flutter/gestures.dart';

class RawGestureRecognizer extends GestureRecognizer {
  RawGestureRecognizer({
    required super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  GestureDisposition? Function(PointerDownEvent)? onPointerDown;
  GestureDisposition? Function(PointerMoveEvent, GestureDisposition?)? onPointerMove;
  GestureDisposition? Function(PointerUpEvent, GestureDisposition?)? onPointerUp;
  GestureDisposition? Function(PointerCancelEvent, GestureDisposition?)? onPointerCancel;
  void Function(PointerEvent)? onWin;
  void Function(PointerEvent)? onLose;

  Map<int, _PointerData>? _pointers = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    assert(_pointers != null);
    assert(!_pointers!.containsKey(event.pointer));

    GestureBinding.instance.pointerRouter.addRoute(event.pointer, _handleEvent, event.transform);
    GestureArenaEntry entry = GestureBinding.instance.gestureArena.add(event.pointer, this);
    final pointerData = _PointerData(entry, event);
    _pointers![event.pointer] = pointerData;
  }

  void _handleEvent(PointerEvent event) {
    assert(_pointers != null);
    assert(_pointers!.containsKey(event.pointer));
    final pointerData = _pointers![event.pointer]!;

    if (event is PointerDownEvent) {
      if (onPointerDown != null) {
        final gestureDisposition = invokeCallback('onPointerDown', () {
          return onPointerDown!(event);
        });
        _resolveGestureArenaEntry(pointerData.gestureArenaEntry, gestureDisposition);
      }
    } else if (event is PointerMoveEvent) {
      _pointers![event.pointer]!.lastPointerEvent = event;
      if (onPointerMove != null) {
        final gestureDisposition = invokeCallback('onPointerMove', () {
          return onPointerMove!(event, pointerData.gestureDisposition);
        });
        _resolveGestureArenaEntry(pointerData.gestureArenaEntry, gestureDisposition);
      }
    } else if (event is PointerUpEvent) {
      GestureDisposition? gestureDisposition = GestureDisposition.accepted;
      if (onPointerUp != null) {
        gestureDisposition = invokeCallback('onPointerUp', () {
          return onPointerUp!(event, pointerData.gestureDisposition);
        });
      }
      // We might be disposed here.
      _removeState(event.pointer, gestureDisposition);
    } else if (event is PointerCancelEvent) {
      GestureDisposition? gestureDisposition = GestureDisposition.rejected;
      if (onPointerCancel != null) {
        gestureDisposition = invokeCallback('onPointerCancel', () {
          return onPointerCancel!(event, pointerData.gestureDisposition);
        });
      }
      // We might be disposed here.
      _removeState(event.pointer, gestureDisposition);
    } else {
      assert(false);
    }
  }

  @override
  void acceptGesture(int pointer) {
    assert(_pointers != null);
    if (!_pointers!.containsKey(pointer)) {
      // We already preemptively forgot about it (e.g. we got an up event).
      return;
    }
    final pointerData = _pointers![pointer]!;
    pointerData.gestureDisposition ??= GestureDisposition.accepted;
    if (onWin != null) {
      invokeCallback('onWin', () => onWin!(pointerData.lastPointerEvent));
    }
  }

  @override
  void rejectGesture(int pointer) {
    assert(_pointers != null);
    if (!_pointers!.containsKey(pointer)) {
      // We already preemptively forgot about it (e.g. we got an up event).
      return;
    }
    final pointerData = _pointers![pointer]!;
    pointerData.gestureDisposition ??= GestureDisposition.rejected;

    if (onLose != null) {
      invokeCallback('onLose', () => onLose!(pointerData.lastPointerEvent));
    }
  }

  void _removeState(int pointer, GestureDisposition? gestureDisposition) {
    if (_pointers == null) {
      // We've already been disposed. It's harmless to skip removing the state
      // for the given pointer because dispose() has already removed it.
      return;
    }
    assert(_pointers!.containsKey(pointer));
    GestureBinding.instance.pointerRouter.removeRoute(pointer, _handleEvent);
    GestureArenaEntry entry = _pointers!.remove(pointer)!.gestureArenaEntry;
    _resolveGestureArenaEntry(entry, gestureDisposition);
  }

  void _resolveGestureArenaEntry(GestureArenaEntry entry, GestureDisposition? gestureDisposition) {
    if (gestureDisposition != null) {
      entry.resolve(gestureDisposition);
    }
  }

  @override
  void dispose() {
    _pointers!.keys.toList().forEach((int pointer) => _removeState(pointer, GestureDisposition.rejected));
    assert(_pointers!.isEmpty);
    _pointers = null;
    super.dispose();
  }

  @override
  String get debugDescription => "Raw gesture recognizer";
}

class _PointerData {
  GestureArenaEntry gestureArenaEntry;
  PointerEvent lastPointerEvent;
  GestureDisposition? gestureDisposition;

  _PointerData(this.gestureArenaEntry, this.lastPointerEvent);
}
