import 'dart:convert';

import 'package:dbus/dbus.dart';
import 'package:nm/nm.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';

part 'connection_per_ssid.g.dart';

@riverpod
class ConnectionPerSsid extends _$ConnectionPerSsid {
  @override
  Future<Map<String, NetworkManagerSettingsConnection>> build(
    String deviceAddress,
  ) async {
    final device = ref.watch(nmDeviceProvider(deviceAddress));

    device.propertiesChanged
        .where(
          (event) => event.contains('availableConnections'),
        )
        .listen((_) => ref.invalidateSelf());

    final mapConnectionPerSsid = <String, NetworkManagerSettingsConnection>{};

    for (final connection in device.availableConnections) {
      final settings = await connection.getSettings();
      final ssid = utf8.decode(
        (settings['802-11-wireless']!['ssid']! as DBusArray)
            .children
            .map((e) => (e as DBusByte).value)
            .toList(),
      );
      mapConnectionPerSsid[ssid] = connection;
    }
    return mapConnectionPerSsid;
  }
}
