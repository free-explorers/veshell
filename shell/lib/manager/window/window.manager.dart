import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/enums.dart';
import 'package:shell/manager/platform_api/platform_api.provider.dart';
import 'package:shell/manager/window/window.dart';
import 'package:shell/shared/state/cursor_position/cursor_position.provider.dart';
import 'package:shell/shared/state/window_stack/window_stack.provider.dart';
import 'package:shell/shared/wayland/xdg_popup/popup_stack.dart';

part 'window.manager.g.dart';

class _WindowManagerState extends ConsumerState<WindowManager> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        ref.read(platformApiProvider.notifier).maximizedWindowSize(
              constraints.maxWidth.toInt(),
              constraints.maxHeight.toInt(),
            );

        Future.microtask(() {
          ref
              .read(windowStackProvider.notifier)
              .setDesktopSize(constraints.biggest.floorToDouble());
        });

        return PortalTarget(
          portalFollower: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: (event) => ref
                .read(cursorPositionProvider.notifier)
                .state = event.localPosition,
            onPointerMove: (event) => ref
                .read(cursorPositionProvider.notifier)
                .state = event.localPosition,
          ),
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final tasks = ref.watch(windowStackProvider).windows;

              return Stack(
                clipBehavior: Clip.none,
                key: ref.watch(windowStackGlobalKeyProvider),
                children: [
                  for (int surfaceId in tasks)
                    ref.watch(windowWidgetProvider(surfaceId)),
                  const PopupStack(),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

@Riverpod(keepAlive: true)
GlobalKey windowStackGlobalKey(WindowStackGlobalKeyRef ref) => GlobalKey();

class WindowManager extends ConsumerStatefulWidget {
  const WindowManager({super.key});

  @override
  ConsumerState<WindowManager> createState() => _WindowManagerState();
}

@Riverpod(keepAlive: true)
Window windowWidget(WindowWidgetRef ref, int surfaceId) {
  return Window(
    key: GlobalKey(),
    surfaceId: surfaceId,
  );
}
