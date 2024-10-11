import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:nm/nm.dart';
import 'package:shell/overview/helm/control_panel/network/provider/device_transfer_monitoring.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';

class DeviceStatus extends ConsumerWidget {
  const DeviceStatus({
    required this.address,
    super.key,
  });

  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(nmDeviceProvider(address));
    final state = device.state;
    return Row(
      children: [
        Text(
          switch (device.state) {
            NetworkManagerDeviceState.unknown => 'Unknown',
            NetworkManagerDeviceState.unavailable => 'Unavailable',
            NetworkManagerDeviceState.disconnected => 'Disconnected',
            NetworkManagerDeviceState.prepare => 'Prepare',
            NetworkManagerDeviceState.config => 'Config',
            NetworkManagerDeviceState.needAuth => 'Need Auth',
            NetworkManagerDeviceState.ipConfig => 'IP Config',
            NetworkManagerDeviceState.ipCheck => 'IP Check',
            NetworkManagerDeviceState.activated => 'Connected',
            NetworkManagerDeviceState.deactivating => 'Deactivating',
            NetworkManagerDeviceState.failed => 'Failed',
            NetworkManagerDeviceState.unmanaged => 'Unmanaged',
            NetworkManagerDeviceState.secondaries => 'Secondaries',
          },
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(width: 8),
        if (state == NetworkManagerDeviceState.activated)
          Consumer(
            builder: (context, ref, child) {
              final transferMonitoring = ref.watch(
                deviceTransferMonitoringStateProvider(
                  address,
                ),
              );
              return Row(
                children: [
                  Icon(
                    MdiIcons.arrowUp,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(transferMonitoring.transferringBytesPerSecond / 1024).toStringAsFixed(2)} kB/s',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(width: 8),
                  Icon(MdiIcons.arrowDown, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${(transferMonitoring.receivingBytesPerSecond / 1024).toStringAsFixed(2)} kB/s',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
