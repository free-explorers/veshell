import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/control_panel/network/widget/device_status.dart';
import 'package:shell/shared/nm/provider/nm_client.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';
import 'package:shell/shared/widget/expandable_card.dart';

class EthernetControl extends HookConsumerWidget {
  const EthernetControl(
    this.address, {
    super.key,
  });
  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(nmDeviceProvider(address));
    return ExpandableCard(
      builder: (context, isExpanded) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.ethernet,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ethernet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        DeviceStatus(address: address),
                      ],
                    ),
                  ),
                  Switch(
                    value: device.autoconnect,
                    onChanged: (value) async {
                      if (value) {
                        await device.setAutoconnect(true);
                        final client = await ref.read(nmClientProvider.future);
                        await client.activateConnection(device: device);
                      } else {
                        await device.disconnect();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
