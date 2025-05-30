import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nm/nm.dart';

part 'wifi_access_point.freezed.dart';

@freezed
abstract class WifiAccessPoint with _$WifiAccessPoint {
  const factory WifiAccessPoint({
    required String ssid,
    required List<NetworkManagerAccessPoint> accessPoints,
    NetworkManagerSettingsConnection? settingsConnection,
  }) = _WifiAccessPoint;
  const WifiAccessPoint._();

  NetworkManagerAccessPoint? get bestAccessPoint => accessPoints.firstOrNull;
}
