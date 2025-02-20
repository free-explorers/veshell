import 'package:dbus/dbus.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/notification/model/dbus_notification_server.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/model/notification_manager_state.serializable.dart';
import 'package:shell/shared/persistence/persistable_provider.mixin.dart';
import 'package:shell/wayland/provider/pid_to_surface_id.dart';
import 'package:shell/window/provider/window_properties.dart';

part 'notification_manager.g.dart';

@riverpod
class NotificationManager extends _$NotificationManager
    with
        PersistableProvider<NotificationManagerState,
            AutoDisposeNotifierProviderRef<NotificationManagerState>> {
  late DbusNotificationServer _server;

  @override
  String getPersistentFolder() => 'Notification';

  @override
  String getPersistentId() => 'notification_list';

  @override
  NotificationManagerState build() {
    final persistedState = getPersisted(NotificationManagerState.fromJson);
    persistChanges();
    initServer();
    return persistedState ??
        NotificationManagerState(
          notificationMap: <int, Notification>{}.lock,
          lastIndex: 0,
        );
  }

  Future<void> initServer() async {
    final client = DBusClient.session();
    final requestNameReply =
        await client.requestName('org.freedesktop.Notifications');
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
              ref
                  .read(pidToSurfaceIdProvider)
                  .containsKey(newNotification.pid)) {
            appId = ref
                .read(
                  windowPropertiesStateProvider(
                    ref.read(pidToSurfaceIdProvider).get(newNotification.pid!)!,
                  ),
                )
                .appId;
          }
          state = state.copyWith(
            notificationMap: state.notificationMap.add(
              newId,
              Notification(
                id: newId,
                appId: appId,
                dbusNotification: newNotification,
                createdAt: DateTime.now(),
              ),
            ),
            lastIndex: newId,
          );
          return newId;
        }
      },
    );
    await client.registerObject(_server);
  }
}
