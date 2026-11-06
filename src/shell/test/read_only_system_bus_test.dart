import 'package:flutter_test/flutter_test.dart';
import 'package:shell/shared/provider/dbus_client.dart';

void main() {
  bool isRead(String? interface, String name, {String? destination}) =>
      ReadOnlySystemBusClient.isRead(
        destination: destination ?? 'org.freedesktop.login1',
        interface: interface,
        name: name,
      );

  test('an isolated instance reads the host system services', () {
    expect(isRead('org.freedesktop.login1.Manager', 'ListSessions'), isTrue);
    expect(isRead('org.freedesktop.login1.Manager', 'CanPowerOff'), isTrue);
    expect(isRead('org.freedesktop.UPower', 'EnumerateDevices'), isTrue);
    expect(isRead('org.freedesktop.DBus.Properties', 'GetAll'), isTrue);
    expect(
      isRead('org.freedesktop.DBus.ObjectManager', 'GetManagedObjects'),
      isTrue,
    );
    expect(
      isRead(
        'org.freedesktop.DBus',
        'AddMatch',
        destination: 'org.freedesktop.DBus',
      ),
      isTrue,
    );
  });

  test('an isolated instance never acts on them', () {
    expect(isRead('org.freedesktop.login1.Manager', 'PowerOff'), isFalse);
    expect(isRead('org.freedesktop.login1.Manager', 'Reboot'), isFalse);
    expect(isRead('org.freedesktop.login1.Manager', 'Suspend'), isFalse);
    expect(isRead('org.freedesktop.login1.Session', 'Terminate'), isFalse);
    expect(
      isRead('org.freedesktop.NetworkManager', 'ActivateConnection'),
      isFalse,
    );
    expect(isRead('org.bluez.Device1', 'Connect'), isFalse);
    expect(isRead('org.bluez.Adapter1', 'StartDiscovery'), isFalse);
    // Property writes (Wi-Fi on/off, adapter power).
    expect(isRead('org.freedesktop.DBus.Properties', 'Set'), isFalse);
    // "Getaway" is not a query: the prefix must start a word.
    expect(isRead('x.Y', 'Getaway'), isFalse);
  });
}
