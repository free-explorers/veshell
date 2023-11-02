import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/mobile/state/app_drawer_state.dart';

class AppDrawerHandle extends ConsumerWidget {
  const AppDrawerHandle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onPanStart: (DragStartDetails details) {
        ref.read(appDrawerNotifierProvider.notifier).update(
              (state) => state.copyWith(
                dragging: true,
                offset: state.slideDistance,
              ),
            );
      },
      onPanEnd: (DragEndDetails details) {
        ref.read(appDrawerNotifierProvider.notifier).update(
              (state) => state.copyWith(
                dragging: false,
                dragVelocity: details.velocity.pixelsPerSecond.dy,
              ),
            );
      },
      onPanUpdate: (DragUpdateDetails details) {
        ref.read(appDrawerNotifierProvider.notifier).update(
              (state) => state.copyWith(
                offset: (state.offset + details.delta.dy).clamp(0, state.slideDistance),
              ),
            );
      },
      child: Container(
        color: Colors.black.withOpacity(0.5),
        height: 150,
        alignment: Alignment.center,
        child: const Icon(
          Icons.keyboard_arrow_up,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}
