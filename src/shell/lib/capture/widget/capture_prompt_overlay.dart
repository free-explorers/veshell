import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/capture/provider/screen_cast_consent.dart';
import 'package:shell/capture/provider/screenshot_prompt.dart';
import 'package:shell/capture/widget/screen_cast_consent.dart';
import 'package:shell/capture/widget/screen_cast_indicator_bar.dart';
import 'package:shell/capture/widget/screenshot_prompt.dart';
import 'package:shell/file_chooser/provider/file_chooser_request.dart';
import 'package:shell/file_chooser/widget/file_chooser_dialog.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/focused_monitor.dart';

/// Picks the monitor a trusted dialog opens on.
///
/// The file chooser prefers the requesting window's monitor — the compositor
/// resolves the requesting app to a live window and reports the monitor it
/// sits on — so the dialog appears above the requester rather than wherever
/// the keyboard focus happens to be. A request with no resolved window, or a
/// monitor that is no longer connected, falls back to the focused monitor.
String? trustedDialogMonitorName({
  required String? requesterMonitorName,
  required Iterable<String> connectedMonitorNameList,
  required String? focusedMonitorName,
}) {
  if (requesterMonitorName != null &&
      connectedMonitorNameList.contains(requesterMonitorName)) {
    return requesterMonitorName;
  }
  return focusedMonitorName;
}

/// Mounts the portal consent picker, screenshot prompt, file chooser, and
/// persistent cast indicator above a monitor's Navigator.
///
/// Drawn in `MaterialApp.builder`, so a pushed route can never cover them.
/// The trusted dialogs stay frozen on one monitor while their flow is open:
/// moving focus mid-flow must not teleport them. The file chooser opens on
/// the requester's monitor; the capture prompts stay on the monitor focused
/// when they opened. The cast indicator is persistent and shown on every
/// monitor.
class CapturePromptOverlay extends HookConsumerWidget {
  const CapturePromptOverlay({required this.monitorName, super.key});

  final String? monitorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(screenCastConsentProvider);
    final prompt = ref.watch(screenshotPromptProvider);
    final chooser = ref.watch(fileChooserRequestProvider);
    final token =
        consent?.consentToken ?? prompt?.consentToken ?? chooser?.consentToken;

    // The requester's monitor only applies when the file chooser owns the
    // active flow (its token is the one we froze); a capture prompt keeps the
    // focus-frozen monitor.
    final requesterMonitorName = chooser?.consentToken == token
        ? chooser?.monitorName
        : null;
    final connectedMonitorNameList = ref
        .watch(connectedMonitorListProvider)
        .map((monitor) => monitor.name);

    // Freeze the target monitor for the current flow token.
    final frozenToken = useRef<int?>(null);
    final targetMonitor = useRef<String?>(null);
    if (token == null) {
      frozenToken.value = null;
      targetMonitor.value = null;
    } else if (targetMonitor.value == null || frozenToken.value != token) {
      final target = trustedDialogMonitorName(
        requesterMonitorName: requesterMonitorName,
        connectedMonitorNameList: connectedMonitorNameList,
        focusedMonitorName: ref.read(focusedMonitorProvider)?.name,
      );
      if (target != null) {
        frozenToken.value = token;
        targetMonitor.value = target;
      }
    }
    final isPromptTarget =
        token != null &&
        monitorName != null &&
        targetMonitor.value == monitorName;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Align(
            alignment: Alignment.bottomLeft,
            child: ScreenCastIndicatorBar(),
          ),
          if (isPromptTarget) ...[
            const ScreenCastConsentHost(),
            const ScreenshotPromptHost(),
            const FileChooserHost(),
          ],
        ],
      ),
    );
  }
}
