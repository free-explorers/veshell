// This file was generated using the following command and may be overwritten.
// dart-dbus generate-object org.freedesktop.Notifications.xml

import 'package:dbus/dbus.dart';

class OrgFreedesktopNotifications extends DBusObject {
  /// Creates a new object to expose on [path].
  OrgFreedesktopNotifications({
    DBusObjectPath path = const DBusObjectPath.unchecked('/'),
  }) : super(path);

  /// Implementation of org.freedesktop.Notifications.GetCapabilities()
  Future<DBusMethodResponse> doGetCapabilities() async {
    return DBusMethodErrorResponse.failed(
      'org.freedesktop.Notifications.GetCapabilities() not implemented',
    );
  }

  /// Implementation of org.freedesktop.Notifications.Notify()
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
    return DBusMethodErrorResponse.failed(
      'org.freedesktop.Notifications.Notify() not implemented',
    );
  }

  /// Implementation of org.freedesktop.Notifications.CloseNotification()
  Future<DBusMethodResponse> doCloseNotification(int id) async {
    return DBusMethodErrorResponse.failed(
      'org.freedesktop.Notifications.CloseNotification() not implemented',
    );
  }

  /// Implementation of org.freedesktop.Notifications.GetServerInformation()
  Future<DBusMethodResponse> doGetServerInformation() async {
    return DBusMethodErrorResponse.failed(
      'org.freedesktop.Notifications.GetServerInformation() not implemented',
    );
  }

  /// Emits signal org.freedesktop.Notifications.NotificationClosed
  Future<void> emitNotificationClosed(int id, int reason) async {
    await emitSignal(
      'org.freedesktop.Notifications',
      'NotificationClosed',
      [DBusUint32(id), DBusUint32(reason)],
    );
  }

  /// Emits signal org.freedesktop.Notifications.ActionInvoked
  Future<void> emitActionInvoked(int id, String actionKey) async {
    await emitSignal(
      'org.freedesktop.Notifications',
      'ActionInvoked',
      [DBusUint32(id), DBusString(actionKey)],
    );
  }

  /// Emits signal org.freedesktop.Notifications.ActivationToken
  Future<void> emitActivationToken(int id, String activationToken) async {
    await emitSignal(
      'org.freedesktop.Notifications',
      'ActivationToken',
      [DBusUint32(id), DBusString(activationToken)],
    );
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface(
        'org.freedesktop.Notifications',
        methods: [
          DBusIntrospectMethod(
            'GetCapabilities',
            args: [
              DBusIntrospectArgument(
                DBusSignature('as'),
                DBusArgumentDirection.out,
                name: 'capabilities',
              ),
            ],
          ),
          DBusIntrospectMethod(
            'Notify',
            args: [
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'appName',
              ),
              DBusIntrospectArgument(
                DBusSignature('u'),
                DBusArgumentDirection.in_,
                name: 'replacesId',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'appIcon',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'summary',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'body',
              ),
              DBusIntrospectArgument(
                DBusSignature('as'),
                DBusArgumentDirection.in_,
                name: 'actions',
              ),
              DBusIntrospectArgument(
                DBusSignature('a{sv}'),
                DBusArgumentDirection.in_,
                name: 'hints',
              ),
              DBusIntrospectArgument(
                DBusSignature('i'),
                DBusArgumentDirection.in_,
                name: 'expireTimeout',
              ),
              DBusIntrospectArgument(
                DBusSignature('u'),
                DBusArgumentDirection.out,
                name: 'id',
              ),
            ],
          ),
          DBusIntrospectMethod(
            'CloseNotification',
            args: [
              DBusIntrospectArgument(
                DBusSignature('u'),
                DBusArgumentDirection.in_,
                name: 'id',
              ),
            ],
          ),
          DBusIntrospectMethod(
            'GetServerInformation',
            args: [
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.out,
                name: 'name',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.out,
                name: 'vendor',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.out,
                name: 'version',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.out,
                name: 'specVersion',
              ),
            ],
          ),
        ],
        signals: [
          DBusIntrospectSignal(
            'NotificationClosed',
            args: [
              DBusIntrospectArgument(
                DBusSignature('u'),
                DBusArgumentDirection.out,
                name: 'id',
              ),
              DBusIntrospectArgument(
                DBusSignature('u'),
                DBusArgumentDirection.out,
                name: 'reason',
              ),
            ],
          ),
          DBusIntrospectSignal(
            'ActionInvoked',
            args: [
              DBusIntrospectArgument(
                DBusSignature('u'),
                DBusArgumentDirection.out,
                name: 'id',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.out,
                name: 'actionKey',
              ),
            ],
          ),
          DBusIntrospectSignal(
            'ActivationToken',
            args: [
              DBusIntrospectArgument(
                DBusSignature('u'),
                DBusArgumentDirection.out,
                name: 'id',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.out,
                name: 'activationToken',
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == 'org.freedesktop.Notifications') {
      if (methodCall.name == 'GetCapabilities') {
        if (methodCall.values.isNotEmpty) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        return doGetCapabilities();
      } else if (methodCall.name == 'Notify') {
        if (methodCall.signature != DBusSignature('susssasa{sv}i')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        final pid = await getProcessID(client, methodCall.sender);

        return doNotify(
          pid,
          methodCall.values[0].asString(),
          methodCall.values[1].asUint32(),
          methodCall.values[2].asString(),
          methodCall.values[3].asString(),
          methodCall.values[4].asString(),
          methodCall.values[5].asStringArray().toList(),
          methodCall.values[6].asStringVariantDict(),
          methodCall.values[7].asInt32(),
        );
      } else if (methodCall.name == 'CloseNotification') {
        if (methodCall.signature != DBusSignature('u')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        return doCloseNotification(methodCall.values[0].asUint32());
      } else if (methodCall.name == 'GetServerInformation') {
        if (methodCall.values.isNotEmpty) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        return doGetServerInformation();
      } else {
        return DBusMethodErrorResponse.unknownMethod();
      }
    } else {
      return DBusMethodErrorResponse.unknownInterface();
    }
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == 'org.freedesktop.Notifications') {
      return DBusMethodErrorResponse.unknownProperty();
    } else {
      return DBusMethodErrorResponse.unknownProperty();
    }
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    if (interface == 'org.freedesktop.Notifications') {
      return DBusMethodErrorResponse.unknownProperty();
    } else {
      return DBusMethodErrorResponse.unknownProperty();
    }
  }
}

Future<int?> getProcessID(DBusClient? client, String? sender) async {
  if (client == null || sender == null) return null;
  final object = DBusRemoteObject(
    client,
    name: 'org.freedesktop.DBus',
    path: DBusObjectPath('/org/freedesktop/DBus'),
  );

  final response = await object
      .callMethod('org.freedesktop.DBus', 'GetConnectionUnixProcessID', [
    DBusString(sender),
  ]);

  if (response.returnValues.isNotEmpty) {
    return response.returnValues[0].asUint32();
  }
  return null;
}
