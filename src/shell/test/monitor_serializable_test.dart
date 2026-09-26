import 'package:flutter_test/flutter_test.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';

/// Representative `monitor_layout_changed` payload as produced by the Rust
/// `MyOutput` serializer. The key set is part of the platform contract: the
/// Rust side declares nine fields and must keep serializing exactly these.
Map<String, dynamic> _payload() => {
  'name': 'DP-1',
  'description': 'Acme Panel',
  'physicalProperties': {
    'size': {'width': 600, 'height': 340},
    'make': 'Acme',
    'model': 'Panel',
  },
  'scale': 1.5,
  'location': {'x': 100, 'y': 50},
  'currentMode': {
    'size': {'width': 1920, 'height': 1080},
    'refreshRate': 60000,
  },
  'preferredMode': {
    'size': {'width': 1920, 'height': 1080},
    'refreshRate': 60000,
  },
  'modes': [
    {
      'size': {'width': 1920, 'height': 1080},
      'refreshRate': 60000,
    },
  ],
  'viewId': 42,
};

void main() {
  test('Monitor round-trips the compositor payload', () {
    final monitor = Monitor.fromJson(_payload());

    expect(monitor.name, 'DP-1');
    expect(monitor.viewId, 42);
    expect(monitor.scale, 1.5);
    expect(monitor.location.dx, 100);
    expect(monitor.location.dy, 50);
    expect(monitor.currentMode!.size.width, 1920);
    expect(monitor.currentMode!.refreshRate, 60000);
    expect(monitor.modes, hasLength(1));

    expect(monitor.toJson(), _payload());
  });

  test('the payload carries exactly the nine fields Rust serializes', () {
    expect(
      _payload().keys.toSet(),
      {
        'name',
        'description',
        'physicalProperties',
        'scale',
        'location',
        'currentMode',
        'preferredMode',
        'modes',
        'viewId',
      },
    );
  });

  test('null modes stay nullable across the round-trip', () {
    final payload = _payload()
      ..['currentMode'] = null
      ..['preferredMode'] = null
      ..['modes'] = <Map<String, dynamic>>[];

    final monitor = Monitor.fromJson(payload);

    expect(monitor.currentMode, isNull);
    expect(monitor.preferredMode, isNull);
    expect(monitor.modes, isEmpty);
    expect(monitor.toJson(), payload);
  });
}
