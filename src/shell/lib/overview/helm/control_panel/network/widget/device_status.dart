import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nm/nm.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/helm/control_panel/network/provider/device_transfer_monitoring.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';

class DeviceStatus extends ConsumerWidget {
  const DeviceStatus({required this.address, super.key});

  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(nmDeviceProvider(address));
    final state = device.state;
    return Row(
      children: [
        Text(switch (device.state) {
          NetworkManagerDeviceState.unknown => context.l10n.unknown,
          NetworkManagerDeviceState.unavailable => context.l10n.unavailable,
          NetworkManagerDeviceState.disconnected => context.l10n.disconnected,
          NetworkManagerDeviceState.prepare => context.l10n.prepare,
          NetworkManagerDeviceState.config => context.l10n.config,
          NetworkManagerDeviceState.needAuth => context.l10n.needAuth,
          NetworkManagerDeviceState.ipConfig => context.l10n.ipConfig,
          NetworkManagerDeviceState.ipCheck => context.l10n.ipCheck,
          NetworkManagerDeviceState.activated => context.l10n.connected,
          NetworkManagerDeviceState.deactivating => context.l10n.deactivating,
          NetworkManagerDeviceState.failed => context.l10n.failed,
          NetworkManagerDeviceState.unmanaged => context.l10n.unmanaged,
          NetworkManagerDeviceState.secondaries => context.l10n.secondaries,
        }, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 8),
        if (state == NetworkManagerDeviceState.activated)
          Consumer(
            builder: (context, ref, child) {
              final transferMonitoring = ref.watch(
                deviceTransferMonitoringStateProvider(address),
              );
              return Row(
                children: [
                  const Icon(MdiIcons.arrowUp, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    context.measurement(
                      transferMonitoring.transferringBytesPerSecond / 1024,
                      'kB/s',
                      decimalDigits: 2,
                    ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(width: 8),
                  const Icon(MdiIcons.arrowDown, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    context.measurement(
                      transferMonitoring.receivingBytesPerSecond / 1024,
                      'kB/s',
                      decimalDigits: 2,
                    ),
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
