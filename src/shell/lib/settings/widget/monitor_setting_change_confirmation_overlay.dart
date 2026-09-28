import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/settings/provider/state/monitor_setting_change_confirmation.dart';

/// Full-view confirmation for a pending display change.
///
/// Mounted in every monitor's `MaterialApp.builder` so the prompt is visible
/// on a still-working monitor even when the changed one is unusable. The
/// rollback itself is owned by [MonitorSettingChangeConfirmation], not this
/// widget, so it still happens if no view can draw.
class MonitorSettingChangeConfirmationOverlay extends ConsumerWidget {
  const MonitorSettingChangeConfirmationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(monitorSettingChangeConfirmationProvider);
    if (pending == null) {
      return const SizedBox.shrink();
    }
    return _ConfirmationScrim(pending: pending);
  }
}

class _ConfirmationScrim extends ConsumerStatefulWidget {
  const _ConfirmationScrim({required this.pending});

  final MonitorSettingChange pending;

  @override
  ConsumerState<_ConfirmationScrim> createState() => _ConfirmationScrimState();
}

class _ConfirmationScrimState extends ConsumerState<_ConfirmationScrim> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Drives the countdown; the actual rollback timer lives in the notifier.
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = ref
        .watch(monitorSettingConfirmationTimeoutProvider)
        .inMilliseconds;
    final remaining = widget.pending.deadline
        .difference(DateTime.now())
        .inMilliseconds
        .clamp(0, total);
    final progress = total == 0 ? 0.0 : remaining / total;
    final seconds = (remaining / 1000).ceil();

    return Positioned.fill(
      // Opaque hit testing so the desktop/settings behind the scrim cannot be
      // interacted with while a rollback is pending.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                margin: const EdgeInsets.all(32),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Keep display settings?',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${widget.pending.description}. Reverting in '
                        '$seconds s unless you keep it.',
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => ref
                                .read(
                                  monitorSettingChangeConfirmationProvider
                                      .notifier,
                                )
                                .rollback(),
                            child: const Text('Revert'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => ref
                                .read(
                                  monitorSettingChangeConfirmationProvider
                                      .notifier,
                                )
                                .confirm(),
                            child: const Text('Keep'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
