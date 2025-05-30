import 'package:dbus/dbus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dbus_client.g.dart';

@Riverpod(keepAlive: true)
DBusClient dbusClient(Ref ref) {
  final client = DBusClient.system();
  ref.onDispose(client.close);
  return client;
}
