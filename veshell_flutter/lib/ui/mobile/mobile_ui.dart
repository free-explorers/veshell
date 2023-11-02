import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/mobile/app_drawer/app_drawer.dart';
import 'package:zenith/ui/mobile/quick_settings/status_bar_with_quick_settings.dart';
import 'package:zenith/ui/mobile/state/mobile_lock_screen_widget_state.dart';
import 'package:zenith/ui/mobile/task_switcher/task_switcher.dart';
import 'package:zenith/ui/mobile/virtual_keyboard/with_virtual_keyboard.dart';

class MobileUi extends ConsumerWidget {
  const MobileUi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Preload providers.
    ref.read(mobileLockScreenStateProvider);

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Image.asset("assets/images/background.jpg", fit: BoxFit.cover),
        SafeArea(
          child: WithVirtualKeyboard(
            viewId: 0,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => const TaskSwitcher(
                    spacing: 20,
                  ),
                ),
                OverlayEntry(builder: (_) => const AppDrawer()),
              ],
            ),
          ),
        ),
        const RepaintBoundary(
          child: StatusBarWithQuickSettings(),
        ),
      ],
    );
  }
}
