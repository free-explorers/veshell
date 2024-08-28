import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/systemd/provider/session.dart';

class SessionControls extends HookConsumerWidget {
  const SessionControls({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () {
                ref.read(sessionProvider.notifier).lock();
              },
              style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
              icon: Icon(MdiIcons.lock),
            ),
            IconButton(
              onPressed: () {
                ref.read(sessionProvider.notifier).logout();
              },
              style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
              icon: Icon(MdiIcons.logout),
            ),
            IconButton(
              onPressed: () {},
              icon: Icon(MdiIcons.powerSleep),
              style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
            ),
            IconButton(
              onPressed: () {
                ref.read(sessionProvider.notifier).reboot();
              },
              icon: Icon(MdiIcons.restart),
              style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
            ),
            IconButton(
              onPressed: () {
                ref.read(sessionProvider.notifier).shutdown();
              },
              style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
              icon: Icon(MdiIcons.power),
            ),
          ],
        ),
      ),
    );
  }
}
