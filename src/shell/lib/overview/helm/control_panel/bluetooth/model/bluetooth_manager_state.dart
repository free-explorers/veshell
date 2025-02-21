import 'package:freezed_annotation/freezed_annotation.dart';

part 'bluetooth_manager_state.freezed.dart';

@freezed
class BluetoothManagerState with _$BluetoothManagerState {
  factory BluetoothManagerState({
    required bool powered,
    required bool discovering,
  }) = _BluetoothManagerState;
}
