import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/provider/notification_manager.dart';

part 'notification_list.g.dart';

@riverpod
class NotificationList extends _$NotificationList {
  @override
  IList<Notification> build() {
    // Synthesized attention notifications are transient popups: they must not
    // appear in the notification center (nor in the Helm badge count), which
    // is the persisted history of real D-Bus notifications.
    return ref
        .watch(notificationManagerProvider)
        .notificationMap
        .where((_, notification) => !notification.isSynthetic)
        .toValueIList(
          sort: true,
          compare: (a, b) => b.id.compareTo(a.id),
        );
  }
}
