import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/provider/notification_manager.dart';

part 'notification_list.g.dart';

@riverpod
class NotificationList extends _$NotificationList {
  @override
  IList<Notification> build() {
    return ref.watch(notificationManagerProvider).notificationMap.toValueIList(
          sort: true,
          compare: (a, b) => b.id.compareTo(a.id),
        );
  }
}
