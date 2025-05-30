import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/provider/bluetooth_device.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/widget/bluetooth_device_icon.dart';

class BluetoothDeviceListTile extends HookConsumerWidget {
  const BluetoothDeviceListTile(
    this.address, {
    super.key,
  });

  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(bluetoothDeviceStateProvider(address))!;
    final bluezDevice = device.bluezDevice;
    if (bluezDevice.paired) {
      return ListTile(
        leading: BluetoothDeviceIcon(bluezDevice.icon),
        title: Text(bluezDevice.alias),
        trailing: bluezDevice.connected
            ? IconButton(
                icon: const Icon(MdiIcons.bluetoothOff),
                onPressed: bluezDevice.disconnect,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (device.connecting)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(MdiIcons.bluetoothConnect),
                      onPressed: ref
                          .read(bluetoothDeviceStateProvider(address).notifier)
                          .connect,
                    ),
                  IconButton(
                    icon: const Icon(
                      MdiIcons.delete,
                    ),
                    onPressed: () =>
                        bluezDevice.adapter.removeDevice(bluezDevice),
                  ),
                ],
              ),
      );
    } else {
      return ListTile(
        onTap: ref.read(bluetoothDeviceStateProvider(address).notifier).pair,
        leading: BluetoothDeviceIcon(bluezDevice.icon),
        title: Text(bluezDevice.alias),
        trailing: Padding(
          padding: const EdgeInsets.all(8),
          child: device.pairing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(),
                )
              : const Icon(MdiIcons.plus),
        ),
      );
    }
  }
}
