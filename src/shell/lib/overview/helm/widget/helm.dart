import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/notification/provider/notification_list.dart';
import 'package:shell/overview/helm/control_panel/widget/control_panel.dart';
import 'package:shell/overview/helm/control_panel/widget/session_controls.dart';
import 'package:shell/overview/helm/monitoring_panel/widget/monitoring_panel.dart';
import 'package:shell/overview/helm/notification_panel/widget/notification_panel.dart';
import 'package:shell/overview/helm/widget/panel_column.dart';

/// Minimum width a single Helm column needs to lay out its cards comfortably.
const _minPanelWidth = 420.0;

/// Gap between two Helm columns.
const _panelGap = 8.0;

/// The dashboard shown when the overview has no ephemeral window.
///
/// The layout adapts to the available space:
///  * wide enough for three columns: control, monitoring and notifications
///    side by side;
///  * tighter: control and monitoring are merged into a single column next to
///    notifications, with the session controls pinned at the bottom;
///  * narrow (small or split screens, portrait): a tab bar switches between the
///    merged column and the notifications.
class Helm extends StatelessWidget {
  const Helm({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableColumns =
            ((constraints.maxWidth + _panelGap) / (_minPanelWidth + _panelGap))
                .floor();
        if (availableColumns >= 3) {
          return const _ThreeColumnLayout();
        }
        if (availableColumns == 2) {
          return const _MergedLayout();
        }
        return const _TabbedLayout();
      },
    );
  }
}

class _ThreeColumnLayout extends StatelessWidget {
  const _ThreeColumnLayout();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: PanelColumn(
            footer: SessionControls(),
            children: [ControlPanel()],
          ),
        ),
        SizedBox(width: _panelGap),
        Expanded(child: PanelColumn(children: [MonitoringPanel()])),
        SizedBox(width: _panelGap),
        Expanded(child: NotificationPanel()),
      ],
    );
  }
}

class _MergedLayout extends StatelessWidget {
  const _MergedLayout();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: PanelColumn(
            footer: SessionControls(),
            children: [ControlPanel(), MonitoringPanel()],
          ),
        ),
        SizedBox(width: _panelGap),
        Expanded(child: NotificationPanel()),
      ],
    );
  }
}

class _TabbedLayout extends ConsumerWidget {
  const _TabbedLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationCount = ref.watch(notificationListProvider).length;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar.secondary(
            tabs: [
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MdiIcons.tuneVertical),
                    SizedBox(width: 8),
                    Text('Controls'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Badge(
                      isLabelVisible: notificationCount > 0,
                      label: Text('$notificationCount'),
                      child: const Icon(MdiIcons.bell),
                    ),
                    const SizedBox(width: 8),
                    const Text('Notifications'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: _panelGap),
          const Expanded(
            child: TabBarView(
              children: [
                PanelColumn(children: [ControlPanel(), MonitoringPanel()]),
                NotificationPanel(),
              ],
            ),
          ),
          const Divider(height: 2),
          const SizedBox(height: 8),
          const SessionControls(),
        ],
      ),
    );
  }
}
