import 'dart:convert';

import 'package:nm/nm.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/model/wifi_access_point.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/provider/connection_per_ssid.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';

part 'wifi_access_point_list.g.dart';

@riverpod
class WifiAccessPointList extends _$WifiAccessPointList {
  @override
  List<WifiAccessPoint> build(String address) {
    final device = ref.watch(nmDeviceProvider(address));

    final wireless = device.wireless!;

    final connectionPerSsid =
        ref.watch(connectionPerSsidProvider(address)).valueOrNull ?? {};

    final listenToChanges = wireless.propertiesChanged.listen((event) {
      if (event.contains('AccessPoints')) {
        ref.invalidateSelf();
      }
    });
    ref.onDispose(listenToChanges.cancel);
    final ssidToWifiAccessPoint = <String, WifiAccessPoint>{};
    for (final entry in connectionPerSsid.entries) {
      ssidToWifiAccessPoint[entry.key] = WifiAccessPoint(
        ssid: entry.key,
        accessPoints: [],
        settingsConnection: entry.value,
      );
    }
    for (final accessPoint in wireless.accessPoints) {
      if (accessPoint.mode != NetworkManagerWifiMode.mesh) {
        final ssid = utf8.decode(accessPoint.ssid);
        if (ssidToWifiAccessPoint.containsKey(ssid)) {
          ssidToWifiAccessPoint[ssid] = ssidToWifiAccessPoint[ssid]!.copyWith(
            accessPoints: [
              ...ssidToWifiAccessPoint[ssid]!.accessPoints,
              accessPoint,
            ],
          );
        } else {
          ssidToWifiAccessPoint[ssid] = WifiAccessPoint(
            ssid: ssid,
            accessPoints: [accessPoint],
          );
        }
      }
    }
    return ssidToWifiAccessPoint.values.toList();
  }
}
