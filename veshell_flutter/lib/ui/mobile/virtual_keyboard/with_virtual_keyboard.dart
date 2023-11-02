import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';
import 'package:zenith/ui/mobile/state/task_switcher_state.dart';
import 'package:zenith/ui/mobile/state/virtual_keyboard_state.dart';
import 'package:zenith/ui/mobile/virtual_keyboard/animated_virtual_keyboard.dart';
import 'package:zenith/ui/mobile/virtual_keyboard/layouts.dart';

class WithVirtualKeyboard extends ConsumerStatefulWidget {
  final int viewId;
  final Widget child;

  const WithVirtualKeyboard({
    Key? key,
    required this.viewId,
    required this.child,
  }) : super(key: key);

  @override
  ConsumerState<WithVirtualKeyboard> createState() => WithVirtualKeyboardState();
}

class WithVirtualKeyboardState extends ConsumerState<WithVirtualKeyboard> with SingleTickerProviderStateMixin {
  final key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, WidgetRef ref, Widget? child) {
        if (widget.viewId != 0) {
          ref.watch(taskSwitcherStateNotifierProvider.select((v) => v.constraintsChanged));
          final constraints = taskSwitcherConstraints;
          final virtualKeyboard = ref.watch(virtualKeyboardStateNotifierProvider(widget.viewId));

          ref.read(xdgToplevelStatesProvider(widget.viewId).notifier)
            ..maximize(true)
            ..resize(
              constraints.maxWidth.toInt(),
              virtualKeyboard.activated && !virtualKeyboard.size.isEmpty
                  ? (constraints.maxHeight - virtualKeyboard.size.height).toInt()
                  : constraints.maxHeight.toInt(),
            );
        }
        return child!;
      },
      child: AnimatedVirtualKeyboard(
        key: key,
        id: widget.viewId,
        onDismiss: () => ref.read(platformApiProvider.notifier).hideKeyboard(widget.viewId),
        onCharacter: (String char) => ref.read(platformApiProvider.notifier).insertText(widget.viewId, char),
        onKeyCode: (KeyCode keyCode) =>
            ref.read(platformApiProvider.notifier).emulateKeyCode(widget.viewId, keyCode.code),
        child: widget.child,
      ),
    );
  }
}
