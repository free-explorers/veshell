// This file was generated using the following command and may be overwritten.
// dart-dbus generate-object org.freedesktop.PolicyKit1.AuthenticationAgent.xml

import 'package:dbus/dbus.dart';

class OrgFreedesktopPolicyKit1AuthenticationAgent extends DBusObject {
  /// Creates a new object to expose on [path].
  OrgFreedesktopPolicyKit1AuthenticationAgent({
    DBusObjectPath path = const DBusObjectPath.unchecked('/'),
  }) : super(path);

  /// Implementation of org.freedesktop.PolicyKit1.AuthenticationAgent.BeginAuthentication()
  Future<DBusMethodResponse> doBeginAuthentication(
    String actionId,
    String message,
    String iconName,
    Map<String, String> details,
    String cookie,
    List<List<DBusValue>> identities,
  ) async {
    return DBusMethodErrorResponse.failed(
      'org.freedesktop.PolicyKit1.AuthenticationAgent.BeginAuthentication() not implemented',
    );
  }

  /// Implementation of org.freedesktop.PolicyKit1.AuthenticationAgent.CancelAuthentication()
  Future<DBusMethodResponse> doCancelAuthentication(String cookie) async {
    return DBusMethodErrorResponse.failed(
      'org.freedesktop.PolicyKit1.AuthenticationAgent.CancelAuthentication() not implemented',
    );
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface(
        'org.freedesktop.PolicyKit1.AuthenticationAgent',
        methods: [
          DBusIntrospectMethod(
            'BeginAuthentication',
            args: [
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'action_id',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'message',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'icon_name',
              ),
              DBusIntrospectArgument(
                DBusSignature('a{ss}'),
                DBusArgumentDirection.in_,
                name: 'details',
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'cookie',
              ),
              DBusIntrospectArgument(
                DBusSignature('a(sa{sv})'),
                DBusArgumentDirection.in_,
                name: 'identities',
              ),
            ],
          ),
          DBusIntrospectMethod(
            'CancelAuthentication',
            args: [
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'cookie',
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    print('polkit handleMethodCall $methodCall');

    if (methodCall.interface ==
        'org.freedesktop.PolicyKit1.AuthenticationAgent') {
      if (methodCall.name == 'BeginAuthentication') {
        if (methodCall.signature != DBusSignature('sssa{ss}sa(sa{sv})')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        return doBeginAuthentication(
          methodCall.values[0].asString(),
          methodCall.values[1].asString(),
          methodCall.values[2].asString(),
          methodCall.values[3].asDict().map(
                (key, value) => MapEntry(key.asString(), value.asString()),
              ),
          methodCall.values[4].asString(),
          methodCall.values[5]
              .asArray()
              .map((child) => child.asStruct())
              .toList(),
        );
      } else if (methodCall.name == 'CancelAuthentication') {
        if (methodCall.signature != DBusSignature('s')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        return doCancelAuthentication(methodCall.values[0].asString());
      } else {
        return DBusMethodErrorResponse.unknownMethod();
      }
    } else {
      return DBusMethodErrorResponse.unknownInterface();
    }
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == 'org.freedesktop.PolicyKit1.AuthenticationAgent') {
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
    if (interface == 'org.freedesktop.PolicyKit1.AuthenticationAgent') {
      return DBusMethodErrorResponse.unknownProperty();
    } else {
      return DBusMethodErrorResponse.unknownProperty();
    }
  }
}
