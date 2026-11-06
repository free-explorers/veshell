import 'package:bluez/bluez.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/provider/dbus_client.dart';

part 'bluez_client.g.dart';

@riverpod
Future<BlueZClient> BluezClient(Ref ref) async {
  final bus = restrictedSystemBus();
  final client = BlueZClient(bus: bus);
  ref.onDispose(() => bus?.close());

  await client.connect();
  return client;
}
