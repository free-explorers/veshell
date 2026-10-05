import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_hints.serializable.freezed.dart';
part 'notification_hints.serializable.g.dart';

@freezed
abstract class NotificationHints with _$NotificationHints {
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

    /// The freedesktop `value` hint: a progress bar value from 0 to 100. System
    /// notifications (volume, brightness) use it to render their level bar.
    int? value,
  }) = _NotificationHints;

  factory NotificationHints.fromJson(Map<String, dynamic> json) =>
      _$NotificationHintsFromJson(json);
}
