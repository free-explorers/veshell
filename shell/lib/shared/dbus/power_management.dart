import 'package:dbus/dbus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veshell/shared/dbus/dbus.provider.dart';

DBusRemoteObject _getLoginDbusObject(WidgetRef ref) {
  return DBusRemoteObject(
    ref.read(dbusSystemBusProvider),
    name: 'org.freedesktop.login1',
    path: DBusObjectPath('/org/freedesktop/login1'),
  );
}

Future<void> powerOff(WidgetRef ref) {
  var object = _getLoginDbusObject(ref);
  const interactive = DBusBoolean(false);
  return object
      .callMethod('org.freedesktop.login1.Manager', 'PowerOff', [interactive]);
}

Future<void> reboot(WidgetRef ref) {
  var object = _getLoginDbusObject(ref);
  const interactive = DBusBoolean(false);
  return object
      .callMethod('org.freedesktop.login1.Manager', 'Reboot', [interactive]);
}
