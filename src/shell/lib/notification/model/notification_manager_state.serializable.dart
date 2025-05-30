import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/notification/model/notification.serializable.dart';

part 'notification_manager_state.serializable.freezed.dart';
part 'notification_manager_state.serializable.g.dart';

@freezed
abstract class NotificationManagerState with _$NotificationManagerState {
  factory NotificationManagerState({
    required IMap<int, Notification> notificationMap,
    required int lastIndex,
  }) = _NotificationManagerState;
  NotificationManagerState._();

  factory NotificationManagerState.fromJson(Map<String, dynamic> json) =>
      _$NotificationManagerStateFromJson(json);
}
