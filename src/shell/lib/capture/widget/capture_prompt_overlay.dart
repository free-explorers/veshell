import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/capture/provider/screen_cast_consent.dart';
import 'package:shell/capture/provider/screenshot_prompt.dart';
import 'package:shell/capture/widget/screen_cast_consent.dart';
import 'package:shell/capture/widget/screen_cast_indicator_bar.dart';
import 'package:shell/capture/widget/screenshot_prompt.dart';
import 'package:shell/monitor/provider/focused_monitor.dart';

/// Mounts the portal consent picker, screenshot prompt, and persistent cast
/// indicator above a monitor's Navigator.
///
/// Drawn in `MaterialApp.builder`, so a pushed route can never cover them.
/// The picker and prompt stay frozen on the monitor that was focused when
/// the flow opened: moving focus mid-flow must not teleport the dialog.
/// The cast indicator is persistent and shown on every monitor.
class CapturePromptOverlay extends HookConsumerWidget {
  const CapturePromptOverlay({required this.monitorName, super.key});

  final String? monitorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(screenCastConsentProvider);
    final prompt = ref.watch(screenshotPromptProvider);
    final token = consent?.consentToken ?? prompt?.consentToken;

    // Freeze the target monitor for the current flow token.
    final frozenToken = useRef<int?>(null);
    final targetMonitor = useRef<String?>(null);
    if (token == null) {
      frozenToken.value = null;
      targetMonitor.value = null;
    } else if (targetMonitor.value == null || frozenToken.value != token) {
      final target = ref.read(focusedMonitorProvider)?.name;
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
          ],
        ],
      ),
    );
  }
}
