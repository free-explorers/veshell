import 'dart:async';

import 'package:flutter/material.dart';
import 'package:glissando/glissando.dart';

class VirtualKeyboardKey extends StatefulWidget {
  final double width;
  final Widget child;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onDoubleTap;
  final bool popUpOnPress;
  final bool repeatOnLongPress;

  const VirtualKeyboardKey({
    super.key,
    required this.width,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.popUpOnPress = true,
    this.repeatOnLongPress = false,
  });

  @override
  State<VirtualKeyboardKey> createState() => _VirtualKeyboardKeyState();
}

class _VirtualKeyboardKeyState extends State<VirtualKeyboardKey> {
  final beingPressed = ValueNotifier<bool>(false);
  OverlayEntry? popupKeyOverlay;
  Timer? longPressTimer;
  Timer? repeatKeyTimer;

  void pointerDown(PointerDownEvent event) {
    pointerUp();
    beingPressed.value = true;

    if (widget.repeatOnLongPress && !event.isGlissandoEvent) {
      longPressTimer = Timer(const Duration(milliseconds: 250), () {
        actuate();
        repeatKeyTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
          actuate();
        });
      });
    }

    if (!widget.popUpOnPress) {
      return;
    }

    var renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || popupKeyOverlay != null) {
      return;
    }

    var size = renderBox.size;
    var overlayRenderObject = Overlay.of(context).context.findRenderObject()!;
    var offset = renderBox.localToGlobal(Offset.zero, ancestor: overlayRenderObject);

    popupKeyOverlay = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          left: offset.dx,
          top: offset.dy - 40,
          child: IgnorePointer(
            child: Transform.scale(
              scale: 1.2,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Card(
                  elevation: 10,
                  margin: const EdgeInsets.all(3),
                  child: Center(
                    child: DefaultTextStyle(
                      style: const TextStyle(color: Colors.black, fontSize: 20),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(popupKeyOverlay!);
  }

  void pointerUp() {
    beingPressed.value = false;
    popupKeyOverlay?.remove();
    popupKeyOverlay = null;
    cancelKeyRepeat();
  }

  void cancelKeyRepeat() {
    longPressTimer?.cancel();
    longPressTimer = null;
    repeatKeyTimer?.cancel();
    repeatKeyTimer = null;
  }

  void actuate() {
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: Listener(
        onPointerDown: (PointerDownEvent event) => pointerDown(event),
        onPointerUp: (_) {
          if (repeatKeyTimer == null) {
            actuate();
          }
          pointerUp();
        },
        onPointerCancel: (_) => pointerUp(),
        child: SizedBox(
          width: widget.width,
          height: 50,
          child: ValueListenableBuilder(
            valueListenable: beingPressed,
            builder: (BuildContext context, bool beingPressed, Widget? child) {
              return Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4.0),
                    color: beingPressed ? Colors.grey.shade300 : Theme.of(context).cardColor,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.grey,
                        offset: Offset(0.0, 1.0),
                        blurRadius: 1.0,
                      ),
                    ],
                  ),
                  child: child!,
                ),
              );
            },
            child: Center(
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.black, fontSize: 20),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
