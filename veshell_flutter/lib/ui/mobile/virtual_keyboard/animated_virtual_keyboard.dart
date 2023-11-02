import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/mobile/state/virtual_keyboard_state.dart';
import 'package:zenith/ui/mobile/virtual_keyboard/layouts.dart';
import 'package:zenith/ui/mobile/virtual_keyboard/virtual_keyboard.dart';

class AnimatedVirtualKeyboard extends ConsumerStatefulWidget {
  final int id;
  final VoidCallback onDismiss;
  final void Function(String) onCharacter;
  final void Function(KeyCode) onKeyCode;
  final Widget child;

  const AnimatedVirtualKeyboard({
    super.key,
    required this.id,
    required this.onDismiss,
    required this.onCharacter,
    required this.onKeyCode,
    required this.child,
  });

  @override
  ConsumerState<AnimatedVirtualKeyboard> createState() => AnimatedVirtualKeyboardState();
}

class AnimatedVirtualKeyboardState extends ConsumerState<AnimatedVirtualKeyboard> with SingleTickerProviderStateMixin {
  final key = GlobalKey();
  final overlayKey = GlobalKey<OverlayState>();

  late var slideAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late var animation = CurvedAnimation(
    parent: slideAnimationController,
    curve: Curves.easeOutCubic,
  );

  late ValueNotifier<Animation<Offset>> slideAnimation = ValueNotifier(
    animation.drive(
      Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ),
    ),
  );

  late final keyboardWidget = Align(
    alignment: Alignment.bottomCenter,
    child: RepaintBoundary(
      child: ValueListenableBuilder(
        valueListenable: slideAnimation,
        builder: (_, Animation<Offset> animation, Widget? child) {
          return SlideTransition(
            position: animation,
            child: child!,
          );
        },
        child: ProviderScope(
          overrides: [
            keyboardIdProvider.overrideWithValue(widget.id),
          ],
          child: RepaintBoundary(
            child: VirtualKeyboard(
              key: key,
              onDismiss: () {
                ref.read(virtualKeyboardStateNotifierProvider(widget.id).notifier).activated = false;
                widget.onDismiss();
              },
              onCharacter: widget.onCharacter,
              onKeyCode: widget.onKeyCode,
            ),
          ),
        ),
      ),
    ),
  );

  OverlayEntry? keyboardOverlay;

  void animateForward() {
    slideAnimation.value = animation.drive(
      Tween(
        begin: slideAnimation.value.value,
        end: Offset.zero,
      ),
    );
    slideAnimationController
      ..reset()
      ..forward();

    if (keyboardOverlay == null) {
      keyboardOverlay = newKeyboardOverlay();
      overlayKey.currentState!.insert(keyboardOverlay!);
    }
  }

  void animateBackward() {
    slideAnimation.value = animation.drive(
      Tween(
        begin: slideAnimation.value.value,
        end: const Offset(0, 1),
      ),
    );
    slideAnimationController
      ..reset()
      ..forward();
  }

  void dragKeyboard(double dy) {
    final notifier = ref.read(virtualKeyboardStateNotifierProvider(widget.id).notifier);
    final state = ref.read(virtualKeyboardStateNotifierProvider(widget.id));

    if (state.activated) {
      slideAnimationController.value += dy / state.size.height;
      return;
    }
    notifier.activated = true;
    slideAnimation.value = slideAnimationController.drive(
      Tween(
        begin: slideAnimation.value.value,
        end: Offset.zero,
      ),
    );
    if (keyboardOverlay == null) {
      keyboardOverlay = newKeyboardOverlay();
      overlayKey.currentState!.insert(keyboardOverlay!);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(virtualKeyboardStateNotifierProvider(widget.id).select((value) => value.activated), (previous, next) {
      next ? animateForward() : animateBackward();
    });

    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? child) {
        final virtualKeyboard = ref.watch(virtualKeyboardStateNotifierProvider(widget.id));

        if (virtualKeyboard.activated && virtualKeyboard.size.isEmpty) {
          SchedulerBinding.instance.addPostFrameCallback(_determineVirtualKeyboardSize);
        }

        return child!;
      },
      child: ClipRect(
        child: Overlay(
          key: overlayKey,
          initialEntries: [
            OverlayEntry(builder: (_) => widget.child),
          ],
        ),
      ),
    );
  }

  void _determineVirtualKeyboardSize(Duration timestamp) {
    var context = key.currentContext;
    if (context == null) {
      return;
    }
    final size = context.size;
    if (size == null) {
      return;
    }
    ref.read(virtualKeyboardStateNotifierProvider(widget.id).notifier).size = size;
  }

  OverlayEntry? newKeyboardOverlay() {
    return OverlayEntry(
      builder: (_) => keyboardWidget,
    );
  }
}
