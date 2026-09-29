import 'package:dbus/dbus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mpris_dbus_client.g.dart';

/// The session-bus connection MPRIS players live on.
///
/// Unlike the system-bus [DBusClient], MPRIS is a per-session service, so this
/// opens `DBusClient.session()`. It is kept alive because reconnecting on every
/// overview toggle would drop every property subscription and player snapshot.
@Riverpod(keepAlive: true)
DBusClient mprisDbusClient(Ref ref) {
  final client = DBusClient.session();
  ref.onDispose(client.close);
  return client;
}
