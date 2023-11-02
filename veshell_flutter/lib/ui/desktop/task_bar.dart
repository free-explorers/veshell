import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/desktop/app_drawer/app_drawer_button.dart';
import 'package:zenith/util/state/ui_mode_state.dart';

part '../../generated/ui/desktop/task_bar.g.dart';

@Riverpod(keepAlive: true)
double taskBarHeight(TaskBarHeightRef ref) => 50.0;

class TaskBar extends ConsumerWidget {
  const TaskBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white38,
      child: SizedBox(
        height: ref.watch(taskBarHeightProvider),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
              ),
            ),
            const Expanded(
              child: Align(
                alignment: Alignment.center,
                child: AppDrawerButton(),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () {
                    ref.read(uiModeStateProvider.notifier).state = UiMode.mobile;
                  },
                  icon: const Icon(Icons.phone_android),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
