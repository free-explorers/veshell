import 'package:dbus/dbus.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_hints.serializable.freezed.dart';
part 'notification_hints.serializable.g.dart';

@freezed
class NotificationHints with _$NotificationHints {
  const factory NotificationHints({
    bool? actionIcons,
    String? category,
    String? desktopEntry,
    List<int>? imageData,
    String? imagePath,
    List<int>? iconData,
    bool? resident,
    String? soundFile,
    String? soundName,
    bool? suppressSound,
    bool? transient,
    int? x,
    int? y,
    int? urgency,
  }) = _NotificationHints;

  factory NotificationHints.fromJson(Map<String, dynamic> json) =>
      _$NotificationHintsFromJson(json);

  factory NotificationHints.fromDbusMap(Map<String, DBusValue> hintsMap) {
    return NotificationHints(
      actionIcons: (hintsMap['action-icons'] as DBusBoolean?)?.value,
      category: (hintsMap['category'] as DBusString?)?.value,
      desktopEntry: (hintsMap['desktop-entry'] as DBusString?)?.value,
      imageData: _dbusArrayToIntList(hintsMap['image-data']),
      imagePath: (hintsMap['image-path'] as DBusString?)?.value,
      iconData: _dbusArrayToIntList(hintsMap['icon-data']),
      resident: (hintsMap['resident'] as DBusBoolean?)?.value,
      soundFile: (hintsMap['sound-file'] as DBusString?)?.value,
      soundName: (hintsMap['sound-name'] as DBusString?)?.value,
      suppressSound: (hintsMap['suppress-sound'] as DBusBoolean?)?.value,
      transient: (hintsMap['transient'] as DBusBoolean?)?.value,
      x: toInt(hintsMap['x']),
      y: toInt(hintsMap['y']),
      urgency: toInt(hintsMap['urgency']),
    );
  }

  static List<int>? _dbusArrayToIntList(DBusValue? value) {
    if (value is DBusArray) {
      return value
          .asArray()
          .whereType<DBusUint32>()
          .map((e) => e.value)
          .toList();
    }
    return null;
  }
}

int? toInt(DBusValue? value) {
  // handle DBusUint32 / DBusInt32
  return switch (value) {
    DBusUint32() => value.value,
    DBusInt32() => value.value,
    DBusByte() => value.value,
    _ => null,
  };
}
