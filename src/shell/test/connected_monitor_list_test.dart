import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_layout_received.dart';
import 'package:shell/platform/model/event/monitor_layout_changed/monitor_layout_changed.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

const _mode = Mode(size: Size(1920, 1080), refreshRate: 60000);

Monitor _monitor(String name, {required int viewId}) => Monitor(
  name: name,
  description: '$name panel',
  physicalProperties: const PhysicalProperties(
    size: Size(600, 340),
    make: 'Acme',
    model: 'Panel',
  ),
  scale: 1,
  location: Offset.zero,
  currentMode: _mode,
  preferredMode: _mode,
  modes: const [_mode],
  viewId: viewId,
);

PlatformEvent _layoutEvent(int revision, List<Monitor> monitors) =>
    PlatformEvent.monitorLayoutChanged(
      method: 'monitor_layout_changed',
      message: MonitorLayoutChangedMessage(
        revision: revision,
        monitors: monitors,
      ),
    );

List<Monitor> _twoMonitors() => [
  _monitor('DP-1', viewId: 1),
  _monitor('HDMI-1', viewId: 2),
];

Iterable<String> _names(ProviderContainer container) => container
    .read(connectedMonitorListProvider)
    .map((monitor) => monitor.name);

/// A container wired to a stream the test can drive, with the connected list
/// kept alive so it observes the events.
ProviderContainer _container(StreamController<PlatformEvent> controller) {
  final container = ProviderContainer(
    overrides: [platformManagerProvider.overrideWithValue(controller.stream)],
  );
  addTearDown(container.dispose);
  final sub = container.listen(connectedMonitorListProvider, (_, _) {});
  addTearDown(sub.close);
  return container;
}

void main() {
  test('starts empty and unannounced', () {
    final controller = StreamController<PlatformEvent>.broadcast();
    addTearDown(controller.close);
    final container = _container(controller);

    expect(container.read(connectedMonitorListProvider), isEmpty);
    expect(container.read(monitorLayoutReceivedProvider), isFalse);
  });

  test('a layout event replaces the list and marks it received', () async {
    final controller = StreamController<PlatformEvent>.broadcast();
    addTearDown(controller.close);
    final container = _container(controller);
    // Subscribe to the "layout received" flag before the event.
    expect(container.read(monitorLayoutReceivedProvider), isFalse);

    controller.add(_layoutEvent(1, _twoMonitors()));
    await Future<void>.delayed(Duration.zero);

    expect(_names(container), ['DP-1', 'HDMI-1']);
    expect(container.read(monitorLayoutReceivedProvider), isTrue);
  });

  test('a later layout event drops a disconnected monitor', () async {
    final controller = StreamController<PlatformEvent>.broadcast();
    addTearDown(controller.close);
    final container = _container(controller);

    controller.add(_layoutEvent(1, _twoMonitors()));
    await Future<void>.delayed(Duration.zero);
    controller.add(_layoutEvent(2, [_monitor('DP-1', viewId: 1)]));
    await Future<void>.delayed(Duration.zero);

    expect(_names(container), ['DP-1']);
  });
}
