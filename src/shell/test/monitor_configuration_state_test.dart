import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/model/monitor_configuration.serializable.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';

/// A [MonitorConfigurationState] with a fixed starting value and no persisted
/// storage, so the notifier's in-memory layout operations can be tested.
class _FakeMonitorConfigurationState extends MonitorConfigurationState {
  _FakeMonitorConfigurationState(this.initial);

  final MonitorConfiguration initial;

  @override
  MonitorConfiguration build(MonitorId monitorId) => initial;
}

ScreenConfiguration _screen(String screenId, {int flex = 50}) =>
    ScreenConfiguration(flex: flex, screenId: screenId);

MonitorConfiguration _configuration(List<ScreenConfiguration> screens) =>
    MonitorConfiguration(
      screenList: screens.lock,
      displayMode: ScreenDisplayMode.splitHorizontal,
    );

late ProviderContainer container;

MonitorConfigurationState notifierFor(MonitorConfiguration configuration) {
  container = ProviderContainer(
    overrides: [
      monitorConfigurationStateProvider(
        'DP-1',
      ).overrideWith(() => _FakeMonitorConfigurationState(configuration)),
    ],
  );
  addTearDown(container.dispose);
  return container.read(monitorConfigurationStateProvider('DP-1').notifier);
}

void main() {
  test('a fresh configuration is empty and not initialized', () {
    final notifier = notifierFor(_configuration([]));

    expect(notifier.state.screenList, isEmpty);
    expect(notifier.isInitialized, isFalse);
  });

  test('adding a screen marks the configuration initialized', () {
    final notifier = notifierFor(
      _configuration([]),
    )..addNewScreenConfiguration('a');

    expect(notifier.isInitialized, isTrue);
    expect(notifier.state.screenList, hasLength(1));
    expect(notifier.state.screenList.single.screenId, 'a');
    expect(notifier.state.screenList.single.flex, 100);
    expect(notifier.state.screenList.single.primaryForMonitor, 'DP-1');
  });

  test('adding a second screen keeps the first as primary', () {
    final notifier = notifierFor(_configuration([]))
      ..addNewScreenConfiguration('a')
      ..addNewScreenConfiguration('b');

    expect(notifier.state.screenList, hasLength(2));
    expect(notifier.state.screenList.first.primaryForMonitor, 'DP-1');
    expect(notifier.state.screenList.last.primaryForMonitor, isNull);
  });

  test('removing a screen removes only the requested id', () {
    final notifier = notifierFor(
      _configuration([_screen('a'), _screen('b')]),
    )..removeScreenConfiguration('a');

    expect(notifier.state.screenList, hasLength(1));
    expect(notifier.state.screenList.single.screenId, 'b');
  });

  test('removing an unknown screen is a no-op', () {
    final notifier = notifierFor(
      _configuration([_screen('a'), _screen('b')]),
    )..removeScreenConfiguration('ghost');

    expect(notifier.state.screenList, hasLength(2));
  });

  test('replacing a screen id keeps flex and position', () {
    final notifier = notifierFor(
      _configuration([_screen('a', flex: 70), _screen('b', flex: 30)]),
    )..replaceScreenIdByScreenId('a', 'c');

    expect(
      notifier.state.screenList.map((screen) => screen.screenId),
      ['c', 'b'],
    );
    expect(
      notifier.state.screenList.map((screen) => screen.flex),
      [70, 30],
    );
  });

  test('swapping two screen ids exchanges them', () {
    final notifier = notifierFor(
      _configuration([_screen('a', flex: 70), _screen('b', flex: 30)]),
    )..swapScreenIds('a', 'b');

    expect(
      notifier.state.screenList.map((screen) => screen.screenId),
      ['b', 'a'],
    );
    expect(
      notifier.state.screenList.map((screen) => screen.flex),
      [70, 30],
    );
  });

  test('updating the flex of one screen leaves the others untouched', () {
    final notifier = notifierFor(
      _configuration([_screen('a'), _screen('b')]),
    );

    notifier.updateFlexForConfiguration(notifier.state.screenList.first, 80);

    expect(
      notifier.state.screenList.map((screen) => screen.flex),
      [80, 50],
    );
  });
}
