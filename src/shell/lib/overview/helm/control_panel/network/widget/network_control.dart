import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nm/nm.dart';
import 'package:shell/overview/helm/control_panel/network/ethernet/widget/ethernet_control.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/wifi_control.dart';
import 'package:shell/overview/helm/widget/panel_column.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';
import 'package:shell/shared/nm/provider/nm_devices.dart';

/// The network control cards, one per network device, or `null` when there are
/// none.
///
/// The cards are grouped in a [Column] with the shared [panelGap] so they keep
/// the same spacing as any other card in the panel.
Widget? networkSection(WidgetRef ref) {
  final nmDevices = ref.watch(nmDevicesProvider);
  if (nmDevices.value == null) {
    return null;
  }
  final cards = <Widget?>[
    for (final address in nmDevices.value!)
      switch (ref.read(nmDeviceProvider(address)).deviceType) {
        NetworkManagerDeviceType.ethernet => EthernetControl(address),
        NetworkManagerDeviceType.wifi => WifiControl(address),
        _ => null,
      },
  ].whereType<Widget>().toList();
  if (cards.isEmpty) {
    return null;
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    spacing: panelGap,
    children: cards,
  );
}
