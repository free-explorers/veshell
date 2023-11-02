import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/enums.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/common/popup_stack.dart';
import 'package:zenith/ui/desktop/state/cursor_position_provider.dart';
import 'package:zenith/ui/desktop/state/window_stack_provider.dart';
import 'package:zenith/ui/desktop/window.dart';

part '../../generated/ui/desktop/window_manager.g.dart';

@Riverpod(keepAlive: true)
GlobalKey windowStackGlobalKey(WindowStackGlobalKeyRef ref) => GlobalKey();

class WindowManager extends ConsumerStatefulWidget {
  const WindowManager({super.key});

  @override
  ConsumerState<WindowManager> createState() => _WindowManagerState();
}

class _WindowManagerState extends ConsumerState<WindowManager> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        ref
            .read(platformApiProvider.notifier)
            .maximizedWindowSize(constraints.maxWidth.toInt(), constraints.maxHeight.toInt());

        Future.microtask(() {
          ref.read(windowStackProvider.notifier).setDesktopSize(constraints.biggest.floorToDouble());
        });

        return PortalTarget(
          portalFollower: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: (event) => ref.read(cursorPositionProvider.notifier).state = event.localPosition,
            onPointerMove: (event) => ref.read(cursorPositionProvider.notifier).state = event.localPosition,
          ),
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final tasks = ref.watch(windowStackProvider).windows;

              return Stack(
                clipBehavior: Clip.none,
                key: ref.watch(windowStackGlobalKeyProvider),
                children: [
                  for (int viewId in tasks) ref.watch(windowWidgetProvider(viewId)),
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
