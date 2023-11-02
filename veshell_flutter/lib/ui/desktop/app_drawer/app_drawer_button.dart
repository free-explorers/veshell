import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/desktop/app_drawer/app_drawer.dart';
import 'package:zenith/ui/desktop/task_bar.dart';

part '../../../generated/ui/desktop/app_drawer/app_drawer_button.g.dart';

@Riverpod(keepAlive: true)
class AppDrawerVisible extends _$AppDrawerVisible {
  @override
  bool build() => false;

  @override
  set state(bool value) {
    super.state = value;
  }

  void update(bool Function(bool) callback) {
    super.state = callback(state);
  }
}

class AppDrawerButton extends ConsumerWidget {
  const AppDrawerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PortalTarget(
      visible: ref.watch(appDrawerVisibleProvider),
      portalFollower: Listener(
        // Hide the drawer when we click anywhere outside the drawer.
        // To detect this type of click we put a invisible listener over the entire screen.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          ref.read(appDrawerVisibleProvider.notifier).state = false;
        },
      ),
      child: PortalTarget(
        visible: ref.watch(appDrawerVisibleProvider),
        closeDuration: const Duration(milliseconds: 200),
        portalFollower: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): () {
              ref.read(appDrawerVisibleProvider.notifier).state = false;
            }
          },
          child: const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: AppDrawer(),
          ),
        ),
        anchor: const Aligned(
          follower: Alignment.bottomCenter,
          target: Alignment.topCenter,
        ),
        child: PortalTarget(
          visible: ref.watch(appDrawerVisibleProvider),
          portalFollower: SizedBox(
            // Invisible box that covers the drawer button which closes the drawer when clicked.
            // This is necessary, otherwise the listener that covers the entire screen will close the
            // drawer on pointer down, and the drawer will immediately reopen on pointer up because
            // the button callback will execute.
            width: ref.watch(taskBarHeightProvider),
            height: ref.watch(taskBarHeightProvider),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => ref.read(appDrawerVisibleProvider.notifier).state = false,
            ),
          ),
          anchor: Aligned.center,
          child: SizedBox(
            height: double.infinity,
            child: IconButton(
              iconSize: 30,
              icon: const Icon(Icons.apps),
              onPressed: () => ref.read(appDrawerVisibleProvider.notifier).update((visible) => !visible),
            ),
          ),
        ),
      ),
    );
  }
}
