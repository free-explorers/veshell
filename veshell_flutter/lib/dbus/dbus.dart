import 'package:dbus/dbus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '../generated/dbus/dbus.g.dart';

@Riverpod(keepAlive: true)
DBusClient dbusSystemBus(DbusSystemBusRef ref) {
  final client = DBusClient.system();
  ref.onDispose(() => client.close());
  return client;
}
