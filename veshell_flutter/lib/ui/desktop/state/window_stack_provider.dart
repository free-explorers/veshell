import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/common/state/tasks_provider.dart';

part '../../../generated/ui/desktop/state/window_stack_provider.freezed.dart';
part '../../../generated/ui/desktop/state/window_stack_provider.g.dart';

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

  void remove(int viewId) {
    assert(state.stack.contains(viewId));
    state = state.copyWith(
      stack: state.stack.remove(viewId),
      animateClosing: state.animateClosing.remove(viewId),
    );
  }

  void setDesktopSize(Size size) {
    state = state.copyWith(
      desktopSize: size,
    );
  }
}

@freezed
class WindowStackState with _$WindowStackState {
  const WindowStackState._();

  const factory WindowStackState({
    required IList<int> stack,
    required ISet<int> animateClosing,
    required Size desktopSize,
  }) = _WindowStackState;

  Iterable<int> get windows => stack;
}
