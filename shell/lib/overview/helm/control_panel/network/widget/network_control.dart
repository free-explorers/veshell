import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nm/nm.dart';
import 'package:shell/overview/helm/control_panel/network/ethernet/widget/ethernet_control.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/wifi_control.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';
import 'package:shell/shared/nm/provider/nm_devices.dart';

class NetworkControl extends ConsumerWidget {
  const NetworkControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nmDevices = ref.watch(nmDevicesProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nmDevices.value != null)
          for (final address in nmDevices.value!)
            switch (ref.read(nmDeviceProvider(address)).deviceType) {
              NetworkManagerDeviceType.ethernet => EthernetControl(address),
              NetworkManagerDeviceType.wifi => WifiControl(address),
              _ => const SizedBox.shrink()
            },
      ],
    );
  }
}
