import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/control_panel/network/widget/device_status.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/provider/wifi_manager.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/available_access_point_list.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/configured_access_point.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/wifi_control_icon.dart';
import 'package:shell/shared/nm/provider/nm_client.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';
import 'package:shell/shared/widget/expandable_card.dart';

class WifiControl extends HookConsumerWidget {
  const WifiControl(
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
                  WifiControlIcon(address),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wifi',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        DeviceStatus(address: address),
                      ],
                    ),
                  ),
                  Switch(
                    value: ref.watch(nmClientProvider).value!.wirelessEnabled,
                    onChanged: (value) async {
                      await ref
                          .watch(nmClientProvider)
                          .value!
                          .setWirelessEnabled(value);
                    },
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  if (!isExpanded)
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ExpandableCard.of(context).expand();
                        ref.read(wifiManagerProvider(address).notifier).scan();
                      },
                      icon: const Icon(MdiIcons.plus),
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  if (isExpanded)
                    Consumer(
                      builder: (context, ref, child) {
                        final wifiManagerState =
                            ref.watch(wifiManagerProvider(address));
                        if (wifiManagerState.isScanning) {
                          return const Padding(
                            padding: EdgeInsets.all(4),
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(),
                            ),
                          );
                        } else {
                          return IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              ref
                                  .read(wifiManagerProvider(address).notifier)
                                  .scan();
                            },
                            icon: const Icon(MdiIcons.refresh),
                            iconSize: 20,
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(4),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
            if (!isExpanded) ConfiguredAccessPoint(address: address),
            if (isExpanded) AvailableAccessPointList(address: address),
          ],
        );
      },
    );
  }
}
