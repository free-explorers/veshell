import 'package:async/async.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/model/meta_bluez_adapter.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/provider/bluez_client.dart';

part 'meta_bluez_adapter.g.dart';

@riverpod
class MetaBluezAdapterState extends _$MetaBluezAdapterState {
  @override
  Future<MetaBluezAdapter> build() async {
    final client = await ref.watch(bluezClientProvider.future);
    final subscription = StreamGroup.merge([
      client.adapterAdded,
      client.adapterRemoved,
      ...client.adapters.map((adapter) => adapter.propertiesChanged),
    ]).listen((_) => ref.invalidateSelf());
    ref.onDispose(subscription.cancel);
    return MetaBluezAdapter(
      powered: client.adapters.any((adapter) => adapter.powered),
      discovering: client.adapters.any((adapter) => adapter.discovering),
    );
  }

  powerOn() async {
    final client = await ref.watch(bluezClientProvider.future);
    for (final adapter in client.adapters) {
      await adapter.setPowered(true);
    }
  }

  powerOff() async {
    final client = await ref.watch(bluezClientProvider.future);
    for (final adapter in client.adapters) {
      await adapter.setPowered(false);
    }
  }

  startDiscovery() async {
    final client = await ref.watch(bluezClientProvider.future);
    for (final adapter in client.adapters) {
      if (!adapter.discovering && adapter.powered) {
        await adapter.startDiscovery();
      }
    }
  }

  stopDiscovery() async {
    final client = await ref.watch(bluezClientProvider.future);
    for (final adapter in client.adapters) {
      if (adapter.discovering && adapter.powered) {
        await adapter.stopDiscovery();
      }
    }
  }
}
