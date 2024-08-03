import 'package:bluez/bluez.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/provider/bluez_client.dart';

part 'bluez_device_added.g.dart';

@riverpod
Stream<BlueZDevice> BluezDeviceAdded(BluezDeviceAddedRef ref) async* {
  final client = await ref.watch(bluezClientProvider.future);
  yield* client.deviceAdded;
}
