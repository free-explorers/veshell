import 'package:dbus/dbus.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/pid_to_meta_window_id.dart';
import 'package:shell/notification/model/dbus_notification_server.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/model/notification_manager_state.serializable.dart';
import 'package:shell/notification/provider/notification_channel.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';

part 'notification_manager.g.dart';

@riverpod
@JsonPersist()
class NotificationManager extends _$NotificationManager {
  late DbusNotificationServer _server;

  @override
  NotificationManagerState build() {
    persist(
      ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );
    initServer();
    return stateOrNull ??
        NotificationManagerState(
          notificationMap: <int, Notification>{}.lock,
          lastIndex: 0,
        );
  }

  Future<void> initServer() async {
    final dbusClient = DBusClient.session();
    final requestNameReply = await dbusClient.requestName(
      'org.freedesktop.Notifications',
    );
    if (requestNameReply == DBusRequestNameReply.primaryOwner) {
      print('Successfully registered as org.freedesktop.Notifications');
    } else {
      print('Failed to register name: $requestNameReply');
    }
    _server = DbusNotificationServer(
      onNewNotification: (newNotification) {
        if (newNotification.replacesId != 0 &&
            state.notificationMap.containsKey(newNotification.replacesId)) {
          return 0;
        } else {
          final newId = state.lastIndex + 1;
          var appId = newNotification.hints.desktopEntry;
          if (appId == null &&
              newNotification.pid != null &&
              ref.read(pidToMetaWindowIdProvider(newNotification.pid!)) !=
                  null) {
            final metaWindowId = ref.read(
              pidToMetaWindowIdProvider(newNotification.pid!),
            );
            appId = ref
                .read(
                  metaWindowStateProvider(metaWindowId!),
                )
                .appId;
          }
          final notification = Notification(
            id: newId,
            appId: appId,
            dbusNotification: newNotification,
            createdAt: DateTime.now(),
          );
          state = state.copyWith(
            notificationMap: state.notificationMap.add(
              newId,
              notification,
            ),
            lastIndex: newId,
          );
          ref
              .read(
                notificationChannelProvider(
                  ref.read(focusedScreenProvider),
                ).notifier,
              )
              .add(notification);
          return newId;
        }
      },
    );
    await dbusClient.registerObject(_server);
  }

  void removeNotification(int id) {
    state = state.copyWith(
      notificationMap: state.notificationMap.remove(id),
    );
  }
}
