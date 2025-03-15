import 'package:dbus/dbus.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/notification_hints.serializable.dart';
import 'package:shell/notification/model/org.freedesktop.Notifications.dart';

class DbusNotificationServer extends OrgFreedesktopNotifications {
  DbusNotificationServer({required this.onNewNotification})
      : super(path: DBusObjectPath('/org/freedesktop/Notifications'));

  final int Function(DbusNotification newNotification) onNewNotification;

  /// Implementation of org.freedesktop.Notifications.GetCapabilities()
  @override
  Future<DBusMethodResponse> doGetCapabilities() async {
    print('NotificationServer - doGetCapabilities');
    return DBusMethodSuccessResponse([
      DBusArray.string(['body', 'actions']),
    ]);
  }

  /// Implementation of org.freedesktop.Notifications.Notify()
  @override
  Future<DBusMethodResponse> doNotify(
    int? pid,
    String appName,
    int replacesId,
    String appIcon,
    String summary,
    String body,
    List<String> actions,
    Map<String, DBusValue> hints,
    int expireTimeout,
  ) async {
    print('NotificationServer - doNotify');
    print(
      '$pid $appName $replacesId $appIcon $summary $body $actions $hints $expireTimeout',
    );
    try {
      final notification = DbusNotification(
        pid: pid,
        appName: appName,
        replacesId: replacesId,
        appIcon: appIcon,
        summary: summary,
        body: body,
        actions: actions,
        hints: NotificationHints.fromDbusMap(hints),
        expireTimeout: expireTimeout,
      );

      return DBusMethodSuccessResponse([
        DBusUint32(
          onNewNotification(notification),
        ),
      ]);
    } catch (e) {
      print(e);
      return DBusMethodErrorResponse.failed(
        'org.freedesktop.Notifications.Notify() failed',
      );
    }
  }

  /// Implementation of org.freedesktop.Notifications.CloseNotification()
  @override
  Future<DBusMethodResponse> doCloseNotification(int id) async {
    print('NotificationServer - doCloseNotification');

    return DBusMethodErrorResponse.failed(
      'org.freedesktop.Notifications.CloseNotification() not implemented',
    );
  }

  /// Implementation of org.freedesktop.Notifications.GetServerInformation()
  @override
  Future<DBusMethodResponse> doGetServerInformation() async {
    print('NotificationServer - doGetServerInformation');
    return DBusMethodSuccessResponse([
      const DBusString('VeshellNotificationServer'),
      const DBusString('Veshell'),
      const DBusString('1.0'),
      const DBusString('1.2'),
    ]);
  }

  /// Emits signal org.freedesktop.Notifications.NotificationClosed
  @override
  Future<void> emitNotificationClosed(int id, int reason) async {
    print('NotificationServer - emitNotificationClosed');

    await emitSignal(
      'org.freedesktop.Notifications',
      'NotificationClosed',
      [DBusUint32(id), DBusUint32(reason)],
    );
  }

  /// Emits signal org.freedesktop.Notifications.ActionInvoked
  @override
  Future<void> emitActionInvoked(int id, String actionKey) async {
    print('NotificationServer - emitActionInvoked');

    await emitSignal(
      'org.freedesktop.Notifications',
      'ActionInvoked',
      [DBusUint32(id), DBusString(actionKey)],
    );
  }

  /// Emits signal org.freedesktop.Notifications.ActivationToken
  @override
  Future<void> emitActivationToken(int id, String activationToken) async {
    print('NotificationServer - emitActivationToken');
    await emitSignal(
      'org.freedesktop.Notifications',
      'ActivationToken',
      [DBusUint32(id), DBusString(activationToken)],
    );
  }
}
