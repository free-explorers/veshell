import 'package:async/async.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/model/bluetooth_manager_state.dart';
import 'package:shell/shared/bluez/provider/bluez_client.dart';

part 'bluetooth_manager.g.dart';

@riverpod
class BluetoothManager extends _$BluetoothManager {
  @override
  Future<BluetoothManagerState> build() async {
    final client = await ref.watch(bluezClientProvider.future);
    final subscription = StreamGroup.merge([
      client.adapterAdded,
      client.adapterRemoved,
      ...client.adapters.map((adapter) => adapter.propertiesChanged),
    ]).listen((_) => ref.invalidateSelf());
    ref.onDispose(subscription.cancel);
    return BluetoothManagerState(
      powered: client.adapters.any((adapter) => adapter.powered),
      discovering: client.adapters.any((adapter) => adapter.discovering),
    );
  }

  Future<void> powerOn() async {
    final client = await ref.watch(bluezClientProvider.future);
    for (final adapter in client.adapters) {
      await adapter.setPowered(true);
    }
  }

  Future<void> powerOff() async {
    final client = await ref.watch(bluezClientProvider.future);
    for (final adapter in client.adapters) {
      await adapter.setPowered(false);
    }
  }

  Future<void> startDiscovery() async {
    final client = await ref.watch(bluezClientProvider.future);
    for (final adapter in client.adapters) {
      if (!adapter.discovering && adapter.powered) {
        await adapter.startDiscovery();
      }
    }
  }

  Future<void> stopDiscovery() async {
    final client = await ref.watch(bluezClientProvider.future);
    for (final adapter in client.adapters) {
      if (adapter.discovering && adapter.powered) {
        await adapter.stopDiscovery();
      }
    }
  }
}
