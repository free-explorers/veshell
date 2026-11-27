import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/model/monitor_configuration.serializable.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/monitor/provider/active_monitor_ids.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/model/screen_manager_state.serializable.dart';
import 'package:shell/screen/provider/screen_manager.dart';

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

/// A screen manager without persisted storage; removing a monitor's last
/// screen asks it to drop that screen.
class _FakeScreenManager extends ScreenManager {
  @override
  ScreenManagerState build() =>
      const ScreenManagerState(screenIds: ISetConst({}));

  @override
  void removeIfEmpty(ScreenId screenId) {}
}

late ProviderContainer container;

MonitorConfigurationState notifierFor(MonitorConfiguration configuration) {
  container = ProviderContainer(
    overrides: [
      screenManagerProvider.overrideWith(_FakeScreenManager.new),
      monitorConfigurationStateProvider(
        'DP-1',
      ).overrideWith(() => _FakeMonitorConfigurationState(configuration)),
    ],
  );
  addTearDown(container.dispose);
  return container.read(monitorConfigurationStateProvider('DP-1').notifier);
}

/// Two connected monitors, `DP-1` and `HDMI-1`, with the given layouts.
ProviderContainer twoMonitors(
  MonitorConfiguration dp,
  MonitorConfiguration hdmi,
) {
  final twoMonitorContainer = ProviderContainer(
    overrides: [
      activeMonitorIdsProvider.overrideWithValue({'DP-1', 'HDMI-1'}.lock),
      monitorConfigurationStateProvider(
        'DP-1',
      ).overrideWith(() => _FakeMonitorConfigurationState(dp)),
      monitorConfigurationStateProvider(
        'HDMI-1',
      ).overrideWith(() => _FakeMonitorConfigurationState(hdmi)),
    ],
  );
  addTearDown(twoMonitorContainer.dispose);
  return twoMonitorContainer;
}

List<String> screenIdsOf(ProviderContainer container, MonitorId monitorId) =>
    container
        .read(monitorConfigurationStateProvider(monitorId))
        .screenList
        .map((screen) => screen.screenId)
        .toList();

void main() {
  test('a fresh configuration is empty and not initialized', () {
    final notifier = notifierFor(_configuration([]));

    expect(notifier.state.screenList, isEmpty);
    expect(notifier.isInitialized, isFalse);
  });

  test('adding a screen marks the configuration initialized', () {
    final notifier = notifierFor(_configuration([]))
      ..addNewScreenConfiguration('a');

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
    final notifier = notifierFor(_configuration([_screen('a'), _screen('b')]))
      ..removeScreenConfiguration('a');

    expect(notifier.state.screenList, hasLength(1));
    expect(notifier.state.screenList.single.screenId, 'b');
  });

  test('removing an unknown screen is a no-op', () {
    final notifier = notifierFor(_configuration([_screen('a'), _screen('b')]))
      ..removeScreenConfiguration('ghost');

    expect(notifier.state.screenList, hasLength(2));
  });

  test('replacing a screen id keeps flex and position', () {
    final notifier = notifierFor(
      _configuration([_screen('a', flex: 70), _screen('b', flex: 30)]),
    )..replaceScreenIdByScreenId('a', 'c');

    expect(notifier.state.screenList.map((screen) => screen.screenId), [
      'c',
      'b',
    ]);
    expect(notifier.state.screenList.map((screen) => screen.flex), [70, 30]);
  });

  test('swapping two screen ids exchanges them', () {
    final notifier = notifierFor(
      _configuration([_screen('a', flex: 70), _screen('b', flex: 30)]),
    )..swapScreenIds('a', 'b');

    expect(notifier.state.screenList.map((screen) => screen.screenId), [
      'b',
      'a',
    ]);
    expect(notifier.state.screenList.map((screen) => screen.flex), [70, 30]);
  });

  test('updating the flex of one screen leaves the others untouched', () {
    final notifier = notifierFor(_configuration([_screen('a'), _screen('b')]));

    notifier.updateFlexForConfiguration(notifier.state.screenList.first, 80);

    expect(notifier.state.screenList.map((screen) => screen.flex), [80, 50]);
  });

  test('showing a screen of another monitor trades the two screens', () {
    final container = twoMonitors(
      _configuration([_screen('a', flex: 70), _screen('b', flex: 30)]),
      _configuration([_screen('c', flex: 100)]),
    );

    container
        .read(monitorConfigurationStateProvider('HDMI-1').notifier)
        .showScreenInPlaceOf('c', 'b');

    expect(screenIdsOf(container, 'DP-1'), ['a', 'c']);
    expect(screenIdsOf(container, 'HDMI-1'), ['b']);
    expect(
      container
          .read(monitorConfigurationStateProvider('DP-1'))
          .screenList
          .map((screen) => screen.flex),
      [70, 30],
    );
  });

  test('a split screen trades places with another monitor\'s screen', () {
    final container = twoMonitors(
      _configuration([_screen('a', flex: 70), _screen('b', flex: 30)]),
      _configuration([_screen('c', flex: 100)]),
    );

    container
        .read(monitorConfigurationStateProvider('DP-1').notifier)
        .showScreenInPlaceOf('b', 'c');

    expect(screenIdsOf(container, 'DP-1'), ['a', 'c']);
    expect(screenIdsOf(container, 'HDMI-1'), ['b']);
  });

  test('showing a screen of the same monitor swaps it in place', () {
    final container = twoMonitors(
      _configuration([_screen('a'), _screen('b')]),
      _configuration([_screen('c')]),
    );

    container
        .read(monitorConfigurationStateProvider('DP-1').notifier)
        .showScreenInPlaceOf('a', 'b');

    expect(screenIdsOf(container, 'DP-1'), ['b', 'a']);
    expect(screenIdsOf(container, 'HDMI-1'), ['c']);
  });

  test('showing a screen no monitor shows replaces the current one', () {
    final container = twoMonitors(
      _configuration([_screen('a'), _screen('b')]),
      _configuration([_screen('c')]),
    );

    container
        .read(monitorConfigurationStateProvider('HDMI-1').notifier)
        .showScreenInPlaceOf('c', 'd');

    expect(screenIdsOf(container, 'DP-1'), ['a', 'b']);
    expect(screenIdsOf(container, 'HDMI-1'), ['d']);
  });

  test('a dragged split comes back when the screen count does', () {
    final notifier = notifierFor(_configuration([]))
      ..addNewScreenConfiguration('a')
      ..addNewScreenConfiguration('b');
    notifier
      ..updateFlexForConfiguration(notifier.state.screenList.first, 80)
      ..updateFlexForConfiguration(notifier.state.screenList.last, 20)
      ..removeLastScreenConfiguration();

    expect(notifier.state.screenList.single.flex, 100);

    notifier.addNewScreenConfiguration('c');

    expect(notifier.state.screenList.map((screen) => screen.flex), [80, 20]);
  });

  test('each screen count keeps its own split', () {
    List<int> flexOf(MonitorConfigurationState notifier) =>
        notifier.state.screenList.map((screen) => screen.flex).toList();

    final notifier = notifierFor(_configuration([]))
      ..addNewScreenConfiguration('a')
      ..addNewScreenConfiguration('b');
    notifier
      ..updateFlexForConfiguration(notifier.state.screenList.first, 70)
      ..updateFlexForConfiguration(notifier.state.screenList.last, 30)
      ..addNewScreenConfiguration('c');
    notifier
      ..updateFlexForConfiguration(notifier.state.screenList[1], 10)
      ..updateFlexForConfiguration(notifier.state.screenList.last, 50);
    final threeScreenSplit = flexOf(notifier);
    notifier.removeLastScreenConfiguration();

    expect(flexOf(notifier), [70, 30]);

    notifier.addNewScreenConfiguration('d');

    expect(flexOf(notifier), threeScreenSplit);
  });

  test('the saved splits survive a JSON round trip', () {
    final configuration = _configuration([_screen('a')]).copyWith(
      flexForScreenCount: {
        '2': [80, 20].lock,
      }.lock,
    );

    expect(
      MonitorConfiguration.fromJson(
        jsonDecode(jsonEncode(configuration.toJson())) as Map<String, dynamic>,
      ),
      configuration,
    );
  });
}
