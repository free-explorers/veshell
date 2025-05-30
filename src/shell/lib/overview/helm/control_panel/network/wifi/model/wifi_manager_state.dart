import 'package:freezed_annotation/freezed_annotation.dart';

part 'wifi_manager_state.freezed.dart';

@freezed
abstract class WifiManagerState with _$WifiManagerState {
  factory WifiManagerState({
    required bool isScanning,
  }) = _WifiManagerState;
}
