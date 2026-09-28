import 'package:dbus/dbus.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/notification_hints.serializable.dart';
import 'package:shell/notification/model/org.freedesktop.Notifications.dart';

class DbusNotificationServer extends OrgFreedesktopNotifications {
  DbusNotificationServer({
    required this.onNewNotification,
    required this.onCloseNotification,
  }) : super(path: DBusObjectPath('/org/freedesktop/Notifications'));

  final int Function(DbusNotification newNotification) onNewNotification;

  /// Called when a client invokes `CloseNotification` for a live notification.
  final void Function(int id) onCloseNotification;

  /// Implementation of org.freedesktop.Notifications.GetCapabilities()
  ///
  /// `body` and `actions` are honored on screen; `persistence` advertises the
  /// `resident` hint and `CloseNotification` support.
  @override
  Future<DBusMethodResponse> doGetCapabilities() async {
    print('NotificationServer - doGetCapabilities');
    return DBusMethodSuccessResponse([
      DBusArray.string(['body', 'actions', 'persistence']),
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
  ///
  /// Closing an unknown or already closed id is a no-op; the spec allows the
  /// server to silently ignore it.
  @override
  Future<DBusMethodResponse> doCloseNotification(int id) async {
    print('NotificationServer - doCloseNotification');
    onCloseNotification(id);
    return DBusMethodSuccessResponse();
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
