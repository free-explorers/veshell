import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

part 'show_key_presses_setting.g.dart';

const showKeyPressesPath = 'keyboard.showKeyPresses';

/// Whether the keys pressed are shown on screen (`keyboard.showKeyPresses`),
/// for screencasts and presentations. Off unless the value is `true`.
@riverpod
bool showKeyPressesSetting(Ref ref) =>
    ref.watch(jsonValueByPathProvider(showKeyPressesPath)) == true;

/// Where on the monitor the keys pressed are shown.
///
/// The enum names are the values stored under `keyboard.keyPressPosition`.
enum KeyPressPosition {
  topLeft(Alignment.topLeft),
  topCenter(Alignment.topCenter),
  topRight(Alignment.topRight),
  bottomLeft(Alignment.bottomLeft),
  bottomCenter(Alignment.bottomCenter),
  bottomRight(Alignment.bottomRight);

  const KeyPressPosition(this.alignment);

  final Alignment alignment;
}

const keyPressPositionPath = 'keyboard.keyPressPosition';
const KeyPressPosition keyPressPositionFallback = KeyPressPosition.bottomRight;

/// The position stored under `keyboard.keyPressPosition`; bottom right when
/// it is missing or unknown.
@riverpod
KeyPressPosition keyPressPositionSetting(Ref ref) =>
    KeyPressPosition.values.asNameMap()[ref.watch(
      jsonValueByPathProvider(keyPressPositionPath),
    )] ??
    keyPressPositionFallback;
