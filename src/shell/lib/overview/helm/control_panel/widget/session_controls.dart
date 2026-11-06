import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/systemd/provider/session.dart';

class SessionControls extends HookConsumerWidget {
  const SessionControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableActions =
        ref.watch(sessionControlAvailabilityProvider).value ?? {};
    if (availableActions.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (availableActions.contains(SessionControlAction.lock))
              Tooltip(
                message: context.l10n.lock,
                preferBelow: true,
                verticalOffset: 32,
                child: IconButton(
                  onPressed: () {
                    ref.read(sessionProvider.notifier).lock();
                  },
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const ShellIcon(MdiIcons.lock),
                ),
              ),
            if (availableActions.contains(SessionControlAction.logout))
              Tooltip(
                message: context.l10n.logOut,
                preferBelow: true,
                verticalOffset: 32,
                child: IconButton(
                  onPressed: () => _perform(
                    context,
                    ref,
                    context.l10n.logOut,
                    (session) => session.logout(),
                  ),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const ShellIcon(MdiIcons.logout),
                ),
              ),
            if (availableActions.contains(SessionControlAction.sleep))
              Tooltip(
                message: context.l10n.sleep,
                preferBelow: true,
                verticalOffset: 32,
                child: IconButton(
                  onPressed: () => _perform(
                    context,
                    ref,
                    context.l10n.sleep,
                    (session) => session.sleep(),
                  ),
                  icon: const ShellIcon(MdiIcons.powerSleep),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            if (availableActions.contains(SessionControlAction.hibernate))
              Tooltip(
                message: context.l10n.hibernate,
                preferBelow: true,
                verticalOffset: 32,
                child: IconButton(
                  onPressed: () async {
                    try {
                      await ref.read(sessionProvider.notifier).hibernate();
                    } catch (error) {
                      if (!context.mounted) return;
                      final message = error is StateError
                          ? error.message
                          : error;
                      await showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(context.l10n.unableToHibernate),
                          content: Text('$message'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(context.l10n.ok),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  icon: const ShellIcon(MdiIcons.snowflake),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            if (availableActions.contains(SessionControlAction.reboot))
              Tooltip(
                message: context.l10n.reboot,
                preferBelow: true,
                verticalOffset: 32,
                child: IconButton(
                  onPressed: () => _perform(
                    context,
                    ref,
                    context.l10n.reboot,
                    (session) => session.reboot(),
                  ),
                  icon: const ShellIcon(MdiIcons.restart),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            if (availableActions.contains(SessionControlAction.shutdown))
              Tooltip(
                message: context.l10n.shutDown,
                preferBelow: true,
                verticalOffset: 32,
                child: IconButton(
                  onPressed: () => _perform(
                    context,
                    ref,
                    context.l10n.shutDown,
                    (session) => session.shutdown(),
                  ),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const ShellIcon(MdiIcons.power),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Runs a session [action], and says so when it fails (logind refused it, a
/// polkit denial, an instance isolated by veshell-probe, which may not act
/// on the host) instead of leaving the click without an answer.
Future<void> _perform(
  BuildContext context,
  WidgetRef ref,
  String label,
  Future<void> Function(Session session) action,
) async {
  try {
    await action(ref.read(sessionProvider.notifier));
  } on Object catch (error) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sessionActionFailed(label)),
        content: Text('$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }
}
