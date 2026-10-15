import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/logs_viewer.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/selected_dialog_for_window.dart';
import 'package:shell/window/widget/window.dart';
import 'package:shell/window/widget/window_dialog_area.dart';

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

    // While the launch has no surface, the window owns a placeholder focus
    // target; once the surface exists, the keyboard goes to the surface node.
    // Handing the keyboard over is what makes the reported bug go away: the
    // surface wraps itself in `SurfaceFocus`, which lets `Enter`/`Space`/
    // `Escape` and the direction keys fall through to the client, while the
    // placeholder has no actions at all, so those keys are not consumed by the
    // overview's search pane either. Without the hand-off the search pane keeps
    // the Flutter focus and its `ActivateIntent` fires, launching another
    // instance instead of reaching the focused client.
    final waitingFocusNode = useFocusNode(debugLabel: 'EphemeralWindowWaiting');
    final activeFocusNode = metaWindowId == null ? waitingFocusNode : focusNode;
    useEffect(() {
      activeFocusNode.requestFocus();
      return null;
    }, [metaWindowId]);

    final content = metaWindowId != null
        ? WindowDialogArea(
            parentWindowId: windowId,
            child: WindowWidget(
              metaWindowId: metaWindowId,
              focusNode: focusNode,
              activationTarget: ref.watch(
                selectedDialogMetaWindowForWindowProvider(windowId),
              ),
            ),
          )
        : Focus(
            // No native window yet: an ephemeral launch may never produce one
            // (a single-instance app that only raises its existing window, a
            // launch that fails). Show the execution logs in a dark terminal
            // container so the tile is never a blank, unclosable card while it
            // waits for its surface.
            focusNode: waitingFocusNode,
            child: _EphemeralLaunchView(
              pid: window.pid,
              onClose: () => ref
                  .read(ephemeralWindowStateProvider(windowId).notifier)
                  .closeWindow(),
            ),
          );

    // Clicking into the window hands it the keyboard as well. The compositor
    // already activates the client on pointer down
    // (`ActivateSurfaceOnPointerDown`); this keeps the Flutter focus in step,
    // so a click after the launch is what `Enter`/`Space` follow.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => activeFocusNode.requestFocus(),
      child: content,
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
