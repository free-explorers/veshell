import 'package:nm/nm.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/provider/dbus_client.dart';

part 'nm_client.g.dart';

@Riverpod(keepAlive: true)
Future<NetworkManagerClient> NmClient(Ref ref) async {
  final bus = restrictedSystemBus();
  final client = NetworkManagerClient(bus: bus);
  ref.onDispose(() => bus?.close());

  await client.connect();
  return client;
}
