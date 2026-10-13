import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/logs_viewer.dart';
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

    final metaWindowId = window.metaWindowId;
    if (metaWindowId != null) {
      return WindowWidget(
        metaWindowId: metaWindowId,
        focusNode: focusNode,
        dialogMetaWindowList: ref
            .watch(dialogSetForWindowProvider(window.windowId))
            .map((element) {
              return ref.read(dialogWindowStateProvider(element)).metaWindowId;
            })
            .toList(),
      );
    }

    // No native window yet: an ephemeral launch may never produce one (a
    // single-instance app that only raises its existing window, a launch that
    // fails). Show the execution logs in a dark terminal container so the tile
    // is never a blank, unclosable card while it waits for its surface.
    return _EphemeralLaunchView(
      pid: window.pid,
      onClose: () => ref
          .read(ephemeralWindowStateProvider(windowId).notifier)
          .closeWindow(),
    );
  }
}

/// The dark container an [EphemeralWindowWidget] shows while its application
/// has not presented a surface: the launch's execution logs, a progress
/// indicator while the process is still starting, and a way out of the wait.
class _EphemeralLaunchView extends StatelessWidget {
  const _EphemeralLaunchView({required this.pid, required this.onClose});

  /// The launched process whose output is streamed, or `null` while the
  /// launcher has not returned yet.
  final int? pid;

  /// Closes the ephemeral window, so a launch that never produces a window
  /// cannot leave the user stuck on this view.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final pid = this.pid;
    return Card(
      child: pid == null
          ? const Center(
              child: SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            )
          : LogsViewer(pid: pid),
    );
  }
}
