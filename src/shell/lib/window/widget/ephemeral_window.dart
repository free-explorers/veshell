import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/widget/window.dart';

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

    if (window.metaWindowId != null) {
      return WindowWidget(
        metaWindowId: window.metaWindowId!,
        focusNode: focusNode,
        dialogMetaWindowList: ref
            .watch(
          dialogSetForWindowProvider(window.windowId),
        )
            .map((element) {
          return ref.read(dialogWindowStateProvider(element)).metaWindowId;
        }).toList(),
      );
    } else {
      return Container();
    }
  }
}
