import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/notification/provider/notification_list.dart';
import 'package:shell/overview/helm/control_panel/audio/widget/audio_control.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/widget/bluetooth_control.dart';
import 'package:shell/overview/helm/control_panel/media_player/widget/media_player_control.dart';
import 'package:shell/overview/helm/control_panel/network/widget/network_control.dart';
import 'package:shell/overview/helm/control_panel/widget/session_controls.dart';
import 'package:shell/overview/helm/monitoring_panel/widget/monitoring_panel.dart';
import 'package:shell/overview/helm/notification_panel/widget/notification_panel.dart';
import 'package:shell/overview/helm/widget/panel_column.dart';

/// Minimum width a single Helm column needs to lay out its cards comfortably.
const _minPanelWidth = 380.0;

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
            ((constraints.maxWidth + panelGap) / (_minPanelWidth + panelGap))
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
    return Row(
      children: [
        Expanded(
          child: PanelColumn(
            footer: const SessionControls(),
            sections: [
              mediaPlayerSection,
              _card(const AudioControl()),
              networkSection,
              _card(const BluetoothControl()),
            ],
          ),
        ),
        const SizedBox(width: panelGap),
        const Expanded(child: PanelColumn(sections: [monitoringSection])),
        const SizedBox(width: panelGap),
        const Expanded(child: NotificationPanel()),
      ],
    );
  }
}

class _MergedLayout extends StatelessWidget {
  const _MergedLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PanelColumn(
            footer: const SessionControls(),
            sections: [
              mediaPlayerSection,
              _card(const AudioControl()),
              networkSection,
              _card(const BluetoothControl()),
              monitoringSection,
            ],
          ),
        ),
        const SizedBox(width: panelGap),
        const Expanded(child: NotificationPanel()),
      ],
    );
  }
}

/// Wraps a single card as a [PanelSection].
PanelSection _card(Widget card) =>
    (_) => card;

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
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(MdiIcons.tuneVertical),
                    const SizedBox(width: 8),
                    Text(context.l10n.controls),
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
                      child: const Icon(MdiIcons.bullhornVariant),
                    ),
                    const SizedBox(width: 8),
                    Text(context.l10n.notifications),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: panelGap),
          Expanded(
            child: TabBarView(
              children: [
                PanelColumn(
                  sections: [
                    mediaPlayerSection,
                    _card(const AudioControl()),
                    networkSection,
                    _card(const BluetoothControl()),
                    monitoringSection,
                  ],
                ),
                const NotificationPanel(),
              ],
            ),
          ),
          const Divider(height: 2),
          const SizedBox(height: panelGap),
          const SessionControls(),
        ],
      ),
    );
  }
}
