import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/available_screen_list.dart';
import 'package:shell/screen/provider/screen_label.dart';
import 'package:shell/screen/provider/screen_manager.dart';

/// Fallback shown on a monitor that has no screens.
///
/// The screen configuration menu lives inside a `ScreenWidget`, so without a
/// monitor-level affordance a monitor the user emptied could never get a screen
/// back. This widget is that affordance: it creates a screen or adopts an
/// unowned one.
class EmptyMonitor extends HookConsumerWidget {
  const EmptyMonitor({required this.monitorName, super.key});

  final MonitorId monitorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableScreens = ref.watch(availableScreenListProvider).toList();
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  MdiIcons.monitorOff,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.noScreensOnMonitor,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.createOrMoveScreen,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _addScreen(ref),
                  icon: const Icon(MdiIcons.plus),
                  label: Text(context.l10n.createScreen),
                ),
                for (final screenId in availableScreens) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _addScreen(ref, screenId),
                    child: _AvailableScreenLabel(screenId: screenId),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addScreen(WidgetRef ref, [ScreenId? screenId]) {
    final newScreenId =
        screenId ?? ref.read(screenManagerProvider.notifier).createNewScreen();
    ref
        .read(monitorConfigurationStateProvider(monitorName).notifier)
        .addNewScreenConfiguration(newScreenId);
  }
}

class _AvailableScreenLabel extends HookConsumerWidget {
  const _AvailableScreenLabel({required this.screenId});

  final ScreenId screenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(screenLabelProvider(screenId));
    return Text(context.l10n.moveScreenHere(label.value ?? screenId));
  }
}
