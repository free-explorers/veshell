import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/notification/widget/notification_area.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/screen/widget/screen_configuration_menu.dart';
import 'package:shell/screen/widget/workspace_list.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/status_bar/provider/status_bar_settings.dart';
import 'package:shell/status_bar/widget/status_bar_items.dart';
import 'package:shell/status_bar/widget/status_top_panel.dart';
import 'package:shell/theme//provider/theme.dart';

class ScreenPanel extends HookConsumerWidget implements PreferredSizeWidget {
  const ScreenPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screenId = CurrentScreenId.of(context);
    // The Helm button spans the status bar's top panel and the workspace
    // panel below it.
    final isTopPanelShown = ref.watch(
      statusBarSettingsProvider.select((settings) => settings.showsTopPanel),
    );
    final helmHeight =
        panelSize + (isTopPanelShown ? StatusTopPanel.height : 0);
    return Material(
      color: theme.colorScheme.surface,
      textStyle: TextStyle(color: theme.colorScheme.onSurface),
      child: SizedBox(
        width: panelSize,
        child: Column(
          children: [
            NotificationArea(
              channel: screenId,
              child: Stack(
                children: [
                  IconButton.filled(
                    constraints: BoxConstraints(
                      minWidth: panelSize,
                      minHeight: helmHeight,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      shape: const RoundedRectangleBorder(),
                      iconSize: 24,
                      // The icon stays centered on the workspace panel's row,
                      // below the top panel's band.
                      padding: EdgeInsets.only(top: helmHeight - panelSize),
                    ),
                    onPressed: () {
                      ref
                          .read(
                            overviewStateProvider(
                              CurrentScreenId.of(context),
                            ).notifier,
                          )
                          .toggle();
                    },
                    icon: const ShellIcon(MdiIcons.shipWheel),
                  ),
                  // The top panel's band carries on over the button.
                  if (isTopPanelShown)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: StatusTopPanel.height,
                      child: IgnorePointer(
                        child: ColoredBox(color: statusBarShade(theme)),
                      ),
                    ),
                ],
              ),
            ),
            const Expanded(child: WorkspaceListView()),
            const ScreenConfigurationMenu(),
          ],
        ),
      ),
    );
  }

  @override
  // TODO: implement preferredSize to expand height
  Size get preferredSize => const Size.fromWidth(panelSize);
}
