import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';

/// Tileable Window that persist when closed
class EphemeralWindowWidget extends HookConsumerWidget {
  /// Const constructor
  const EphemeralWindowWidget({
    required this.windowId,
    required this.focusNode,
    super.key,
  });

  /// The id of the wayland surface
  final EphemeralWindowId windowId;
  final FocusNode focusNode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(ephemeralWindowStateProvider(windowId));
    final metaWindow = ref.watch(metaWindowStateProvider(window.metaWindowId!));

    final dialogWindowIdSet = ref.watch(
      dialogSetForWindowProvider(window.windowId),
    );

    final dialogWindowList = <DialogWindow>[];
    for (final windowId in dialogWindowIdSet) {
      final dialogWindow = ref.read(dialogWindowStateProvider(windowId));
      dialogWindowList.add(dialogWindow);
    }
/* 
    useEffect(
      () {
        if (window.metaWindowId != null) {
          ref.read(waylandManagerProvider.notifier).request(
                ActivateWindowRequest(
                  message: ActivateWindowMessage(
                    metaWindowId: metaWindow.id,
                    activate: true,
                  ),
                ),
              );
        }
        return null;
      },
      [window.metaWindowId],
    );
 */
    if (window.metaWindowId != null) {
/*       return Focus(
        focusNode: focusNode,
        onFocusChange: (value) {
          if (window.metaWindowId != null) {
            ref.read(waylandManagerProvider.notifier).request(
                  ActivateWindowRequest(
                    message: ActivateWindowMessage(
                      metaWindowId: window.metaWindowId!,
                      activate: focusNode.hasFocus,
                    ),
                  ),
                );
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return HookBuilder(
              builder: (context) {
                useEffect(
                  () {
                    ref.read(waylandManagerProvider.notifier).request(
                          ResizeWindowRequest(
                            message: ResizeWindowMessage(
                              metaWindowId: window.metaWindowId!,
                              width: constraints.biggest.width.round(),
                              height: constraints.biggest.height.round(),
                            ),
                          ),
                        );
                    return null;
                  },
                  [constraints],
                );
                return MetaSurfaceWidget(
                  metaWindowId: window.metaWindowId!,
                );
              },
            );
          },
        ),
      ); */
      return Container();
    } else {
      return Container();
    }
  }
}
