import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:nm/src/network_manager_client.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/model/wifi_access_point.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/provider/wifi_access_point_list.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/access_point_icon.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/access_point_label.dart';
import 'package:shell/shared/nm/provider/nm_client.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';

class ConfiguredAccessPoint extends HookConsumerWidget {
  const ConfiguredAccessPoint({
    required this.address,
    super.key,
  });

  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(nmDeviceProvider(address));
    final configuredAccessPoint = ref
        .watch(wifiAccessPointListProvider(address))
        .where(
          (element) =>
              element.settingsConnection != null &&
              element.accessPoints.isNotEmpty,
        )
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final accessPoint in configuredAccessPoint)
          ConfiguredAccesPointTile(accessPoint: accessPoint, device: device),
      ],
    );
  }
}

class ConfiguredAccesPointTile extends HookConsumerWidget {
  const ConfiguredAccesPointTile({
    required this.accessPoint,
    required this.device,
    super.key,
  });

  final WifiAccessPoint accessPoint;
  final NetworkManagerDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = useFuture(accessPoint.settingsConnection!.getSettings());

    final isSelected =
        accessPoint.accessPoints.contains(device.wireless!.activeAccessPoint);

    return ListTile(
      leading: isSelected
          ? const Icon(MdiIcons.check)
          : AccessPointIcon(accessPoint: accessPoint.bestAccessPoint!),
      title: AccessPointLabel(
        accessPoint: accessPoint.bestAccessPoint!,
      ),
      onTap: isSelected
          ? null
          : () {
              ref.read(nmClientProvider).value!.activateConnection(
                    device: device,
                    connection: accessPoint.settingsConnection,
                  );
            },
      trailing: IconButton(icon: const Icon(MdiIcons.pencil), onPressed: () {}),
    );
  }
}
