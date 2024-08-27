import 'package:bluez/bluez.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/bluez/provider/bluez_client.dart';

part 'bluez_device_removed.g.dart';

@riverpod
Stream<BlueZDevice> BluezDeviceRemoved(BluezDeviceRemovedRef ref) async* {
  final client = await ref.watch(bluezClientProvider.future);
  yield* client.deviceRemoved;
}
