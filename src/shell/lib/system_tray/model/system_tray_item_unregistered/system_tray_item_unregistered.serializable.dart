import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'system_tray_item_unregistered.serializable.freezed.dart';
part 'system_tray_item_unregistered.serializable.g.dart';

/// A tray item left: its application hid it or quit.
@freezed
sealed class SystemTrayItemUnregisteredMessage
    with _$SystemTrayItemUnregisteredMessage
    implements PlatformMessage {
  /// Factory
  factory SystemTrayItemUnregisteredMessage({required String id}) =
      _SystemTrayItemUnregisteredMessage;

  factory SystemTrayItemUnregisteredMessage.fromJson(
    Map<String, dynamic> json,
  ) => _$SystemTrayItemUnregisteredMessageFromJson(json);
}
