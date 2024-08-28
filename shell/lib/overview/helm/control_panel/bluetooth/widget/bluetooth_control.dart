import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/provider/bluetooth_manager.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/widget/bluetooth_device_list_tile.dart';
import 'package:shell/shared/bluez/provider/bluez_device.dart';
import 'package:shell/shared/bluez/provider/bluez_devices.dart';

class BluetoothControl extends HookConsumerWidget {
  const BluetoothControl({
    this.isExpanded = false,
    super.key,
  });
  final bool isExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bluetoothManagerState = ref.watch(bluetoothManagerProvider);
    final deviceAddresses =
        ref.watch(bluezDevicesProvider).value ?? <String>{}.lock;
    final devices = deviceAddresses
        .map((address) => ref.watch(bluezDeviceProvider(address)))
        // First connected then paired then unpaired
        .sorted(
      (a, b) {
        if (a.connected == b.connected) {
          if (a.paired == b.paired) {
            return a.name.compareTo(b.name ?? '') ?? 0;
          }
          return (b.paired ?? false) ? 1 : -1;
        }
        return (b.connected ?? false) ? 1 : -1;
      },
    ).toList();

    final connectedDevices =
        devices.where((device) => device.connected).toList();
    final displayedDevices = isExpanded ? devices : connectedDevices;
    return Hero(
      tag: 'bluetooth',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Card(
            elevation: isExpanded ? 32 : 0,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: Icon(
                          MdiIcons.bluetooth,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(
                        width: 16,
                      ),
                      Expanded(
                        child: Text(
                          'Bluetooth',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Switch(
                        value: bluetoothManagerState.value?.powered ?? false,
                        onChanged: (value) {
                          if (value) {
                            ref
                                .read(bluetoothManagerProvider.notifier)
                                .powerOn();
                          } else {
                            ref
                                .read(bluetoothManagerProvider.notifier)
                                .powerOff();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Flexible(
                  flex: isExpanded ? 1 : 0,
                  child: ColoredBox(
                    color: Colors.black12,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemBuilder: (context, index) => BluetoothDeviceListTile(
                        displayedDevices[index].address,
                      ),
                      itemCount: displayedDevices.length,
                    ),
                  ),
                ),
                if (!isExpanded)
                  TextButton(
                    style: TextButton.styleFrom(
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: () {
                      ref
                          .read(bluetoothManagerProvider.notifier)
                          .startDiscovery();
                      final currentContext = context;
                      final currentBox =
                          currentContext.findRenderObject()! as RenderBox;
                      final currentCoordinates = currentBox.localToGlobal(
                        Offset.zero,
                      );
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          opaque: false,
                          barrierColor: Colors.black38,
                          barrierDismissible: true,
                          pageBuilder: (BuildContext context, _, __) {
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: [
                                    Positioned(
                                      top: currentCoordinates.dy - 16,
                                      left: currentCoordinates.dx - 16,
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxHeight:
                                              constraints.biggest.height -
                                                  currentCoordinates.dy +
                                                  16,
                                        ),
                                        width: currentBox.size.width + 32,
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: BluetoothControl(
                                            isExpanded: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                    child: const Text('View more'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
