import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/screen/provider/current_screen_id.dart';
import 'package:shell/screen/widget/workspace_list.dart';
import 'package:shell/theme//provider/theme.dart';

class ScreenPanel extends HookConsumerWidget implements PreferredSizeWidget {
  const ScreenPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      textStyle: TextStyle(color: theme.colorScheme.onSurface),
      child: SizedBox(
        width: panelSize,
        child: Column(
          children: [
            IconButton.filled(
              constraints: const BoxConstraints(
                minWidth: panelSize,
                minHeight: panelSize,
              ),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                shape: const RoundedRectangleBorder(),
                iconSize: 24,
              ),
              onPressed: () {
                ref
                    .read(
                      overviewStateProvider(
                        ref.read(currentScreenIdProvider),
                      ).notifier,
                    )
                    .toggle();
              },
              icon: const Icon(MdiIcons.shipWheel),
            ),
            const Expanded(child: WorkspaceListView()),
          ],
        ),
      ),
    );
  }

  @override
  // TODO: implement preferredSize to expand height
  Size get preferredSize => const Size.fromWidth(panelSize);
}
