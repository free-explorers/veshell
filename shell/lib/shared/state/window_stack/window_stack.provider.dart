import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/state/window_stack/window_stack.model.dart';
import 'package:shell/shared/tasks/tasks.provider.dart';

part 'window_stack.provider.g.dart';

@Riverpod(keepAlive: true)
class WindowStack extends _$WindowStack {
  @override
  WindowStackState build() {
    ref.listen(tasksProvider, (previous, next) {
      if (previous == null) {
        state = state.copyWith(
          stack: next.tasks,
          animateClosing: <int>{}.lock,
        );
      } else {
        var stack = state.stack;
        var animateClosing = state.animateClosing;

        for (final operation in next.diff) {
          if (operation is RemoveDiffOperation<int>) {
            // Delay window removal until the close animation is done.
            // Don't remove it from the stack right away.
            animateClosing = animateClosing.add(operation.element);
          } else {
            stack = operation.applyOn(stack);
          }
        }

        state = state.copyWith(
          stack: stack,
          animateClosing: animateClosing,
        );
      }
    });

    return WindowStackState(
      stack: ref.read(tasksProvider).tasks,
      animateClosing: <int>{}.lock,
      desktopSize: Size.zero,
    );
  }

  void remove(int surfaceId) {
    assert(state.stack.contains(surfaceId));
    state = state.copyWith(
      stack: state.stack.remove(surfaceId),
      animateClosing: state.animateClosing.remove(surfaceId),
    );
  }

  void setDesktopSize(Size size) {
    state = state.copyWith(
      desktopSize: size,
    );
  }
}
