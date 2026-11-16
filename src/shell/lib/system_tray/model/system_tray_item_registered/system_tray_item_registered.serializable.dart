import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'system_tray_item_registered.serializable.freezed.dart';
part 'system_tray_item_registered.serializable.g.dart';

/// An application registered a tray item with the compositor's
/// `org.kde.StatusNotifierWatcher`.
///
/// [busName] and [objectPath] address the item's `org.kde.StatusNotifierItem`
/// object on the session bus; [pid] is the process behind the bus name,
/// resolved by the bus driver.
@freezed
sealed class SystemTrayItemRegisteredMessage
    with _$SystemTrayItemRegisteredMessage
    implements PlatformMessage {
  /// Factory
  factory SystemTrayItemRegisteredMessage({
    required String id,
    required String busName,
    required String objectPath,
    int? pid,
  }) = _SystemTrayItemRegisteredMessage;

  factory SystemTrayItemRegisteredMessage.fromJson(Map<String, dynamic> json) =>
      _$SystemTrayItemRegisteredMessageFromJson(json);
}
