import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dbus_client.g.dart';

/// Whether this instance may act on the host's system services (logind,
/// NetworkManager, BlueZ, UPower). An instance isolated by veshell-probe
/// (`VESHELL_PROBE_ISOLATED=1`) shares the host's system bus, so it only
/// reads from it: a tap on its power or network controls must not log the
/// developer out or turn their Wi-Fi off.
///
/// Debug builds only, like the rest of the probe (it only runs debug builds):
/// in a release build this is constant, and the read-only client below is
/// never used.
final bool hostSystemControlAllowed =
    !kDebugMode || Platform.environment['VESHELL_PROBE_ISOLATED'] != '1';

/// The bus the system services' clients should use: `null` (their own
/// connection to the system bus) normally, a [ReadOnlySystemBusClient] in an
/// isolated instance. The caller closes it.
DBusClient? restrictedSystemBus() =>
    hostSystemControlAllowed ? null : ReadOnlySystemBusClient();

@Riverpod(keepAlive: true)
DBusClient dbusClient(Ref ref) {
  final client = restrictedSystemBus() ?? DBusClient.system();
  ref.onDispose(client.close);
  return client;
}

/// A system bus connection that reads and refuses everything else: method
/// calls other than queries (`Get*`, `List*`, `Can*`, `Enumerate*`), the
/// standard reading interfaces and the bus daemon's own are answered with an
/// access-denied error, and so are property writes.
class ReadOnlySystemBusClient extends DBusClient {
  ReadOnlySystemBusClient()
    : super(
        DBusAddress(
          Platform.environment['DBUS_SYSTEM_BUS_ADDRESS'] ??
              'unix:path=/run/dbus/system_bus_socket',
        ),
      );

  static final _query = RegExp('^(Get|List|Can|Enumerate)[A-Z]');

  static const _readingInterfaces = {
    'org.freedesktop.DBus.ObjectManager',
    'org.freedesktop.DBus.Introspectable',
    'org.freedesktop.DBus.Peer',
  };

  /// Whether a call to [name] on [interface] at [destination] only reads.
  static bool isRead({
    required String? destination,
    required String? interface,
    required String name,
  }) {
    if (destination == 'org.freedesktop.DBus') {
      return true; // The bus itself: names, match rules.
    }
    if (interface == 'org.freedesktop.DBus.Properties') {
      return name == 'Get' || name == 'GetAll';
    }
    return _readingInterfaces.contains(interface) || _query.hasMatch(name);
  }

  @override
  Future<DBusMethodSuccessResponse> callMethod({
    String? destination,
    required DBusObjectPath path,
    String? interface,
    required String name,
    Iterable<DBusValue> values = const [],
    DBusSignature? replySignature,
    bool noReplyExpected = false,
    bool noAutoStart = false,
    bool allowInteractiveAuthorization = false,
  }) {
    if (!isRead(destination: destination, interface: interface, name: name)) {
      return Future.error(
        DBusMethodResponseException(
          DBusMethodErrorResponse.accessDenied(
            'veshell-probe: an isolated instance does not call '
            '$interface.$name on the host system bus',
          ),
        ),
      );
    }
    return super.callMethod(
      destination: destination,
      path: path,
      interface: interface,
      name: name,
      values: values,
      replySignature: replySignature,
      noReplyExpected: noReplyExpected,
      noAutoStart: noAutoStart,
      allowInteractiveAuthorization: allowInteractiveAuthorization,
    );
  }
}
