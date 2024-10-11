import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:nm/nm.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/access_point_icon.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';

class WifiControlIcon extends ConsumerWidget {
  const WifiControlIcon(
    this.address, {
    super.key,
  });
  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(nmDeviceProvider(address));
    final isDisconnected = [
      NetworkManagerDeviceState.disconnected,
      NetworkManagerDeviceState.unavailable,
      NetworkManagerDeviceState.unmanaged,
      NetworkManagerDeviceState.unknown,
    ].contains(device.state);
    return device.wireless!.activeAccessPoint != null
        ? AccessPointIcon(
            accessPoint: device.wireless!.activeAccessPoint!,
            color: Theme.of(context).colorScheme.primary,
          )
        : Icon(
            isDisconnected ? MdiIcons.wifiOff : MdiIcons.wifi,
            color: Theme.of(context).colorScheme.primary,
          );
  }
}
