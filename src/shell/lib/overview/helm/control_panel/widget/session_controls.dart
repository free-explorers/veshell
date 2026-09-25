import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/systemd/provider/session.dart';

class SessionControls extends HookConsumerWidget {
  const SessionControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Tooltip(
              message: 'Lock',
              preferBelow: true,
              verticalOffset: 32,
              child: IconButton(
                onPressed: () {
                  ref.read(sessionProvider.notifier).lock();
                },
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
                icon: const Icon(MdiIcons.lock),
              ),
            ),
            Tooltip(
              message: 'Log out',
              preferBelow: true,
              verticalOffset: 32,
              child: IconButton(
                onPressed: () {
                  ref.read(sessionProvider.notifier).logout();
                },
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
                icon: const Icon(MdiIcons.logout),
              ),
            ),
            Tooltip(
              message: 'Sleep',
              preferBelow: true,
              verticalOffset: 32,
              child: IconButton(
                onPressed: () {
                  ref.read(sessionProvider.notifier).sleep();
                },
                icon: const Icon(MdiIcons.powerSleep),
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
              ),
            ),
            Tooltip(
              message: 'Hibernate',
              preferBelow: true,
              verticalOffset: 32,
              child: IconButton(
                onPressed: () {
                  ref.read(sessionProvider.notifier).hibernate();
                },
                icon: const Icon(MdiIcons.snowflake),
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
              ),
            ),
            Tooltip(
              message: 'Reboot',
              preferBelow: true,
              verticalOffset: 32,
              child: IconButton(
                onPressed: () {
                  ref.read(sessionProvider.notifier).reboot();
                },
                icon: const Icon(MdiIcons.restart),
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
              ),
            ),
            Tooltip(
              message: 'Shut down',
              preferBelow: true,
              verticalOffset: 32,
              child: IconButton(
                onPressed: () {
                  ref.read(sessionProvider.notifier).shutdown();
                },
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
                icon: const Icon(MdiIcons.power),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
