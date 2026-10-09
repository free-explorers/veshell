import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_by_view_id.dart';
import 'package:shell/monitor/provider/platform_focused_view.dart';
import 'package:shell/screen/model/screen_manager_state.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/monitor_for_screen.dart';
import 'package:shell/screen/provider/screen_for_view.dart';
import 'package:shell/screen/provider/screen_manager.dart';

ScreenManagerState _manager(Set<String> screenIds) =>
    ScreenManagerState(screenIds: screenIds.lock);

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

ProviderContainer _container(List<Override> overrides) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('no screens yields no focused screen', () {
    final container = _container([
      screenManagerProvider.overrideWithValue(_manager({})),
    ]);

    expect(container.read(focusedScreenProvider), isNull);
  });

  test('without platform focus the first screen is used', () {
    final container = _container([
      screenManagerProvider.overrideWithValue(_manager({'a', 'b'})),
    ]);

    expect(container.read(focusedScreenProvider), 'a');
  });

  test('platform focus selects that screen through screenForView', () {
    final container = _container([
      screenManagerProvider.overrideWithValue(_manager({'a', 'b'})),
      monitorByViewIdProvider(7).overrideWithValue('DP-1'),
      screenForViewProvider(7).overrideWithValue('b'),
    ]);
    final sub = container.listen(focusedScreenProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(platformFocusedViewIdProvider.notifier).set(7);

    expect(container.read(focusedScreenProvider), 'b');
  });

  test('platform focus without a screen falls back to the first', () {
    final container = _container([
      screenManagerProvider.overrideWithValue(_manager({'a', 'b'})),
      monitorByViewIdProvider(7).overrideWithValue('DP-1'),
      screenForViewProvider(7).overrideWithValue(null),
    ]);
    final sub = container.listen(focusedScreenProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(platformFocusedViewIdProvider.notifier).set(7);

    expect(container.read(focusedScreenProvider), 'a');
  });

  test('unknown platform view keeps the first screen', () {
    final container = _container([
      screenManagerProvider.overrideWithValue(_manager({'a', 'b'})),
      monitorByViewIdProvider(9).overrideWithValue(null),
    ]);
    final sub = container.listen(focusedScreenProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(platformFocusedViewIdProvider.notifier).set(9);

    expect(container.read(focusedScreenProvider), 'a');
  });

  test('setFocusedScreen rejects a screen the manager does not know', () {
    final container = _container([
      screenManagerProvider.overrideWithValue(_manager({'a', 'b'})),
    ]);
    final sub = container.listen(focusedScreenProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(focusedScreenProvider.notifier).setFocusedScreen('ghost');

    expect(container.read(focusedScreenProvider), 'a');
  });

  test('setFocusedScreen(null) clears the focus', () {
    final container = _container([
      screenManagerProvider.overrideWithValue(_manager({'a', 'b'})),
    ]);
    final sub = container.listen(focusedScreenProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(focusedScreenProvider.notifier).setFocusedScreen(null);

    expect(container.read(focusedScreenProvider), isNull);
  });

  test('a manual screen choice survives a rebuild in the same monitor', () {
    final container = _container([
      screenManagerProvider.overrideWithValue(_manager({'a', 'b'})),
      monitorByViewIdProvider(7).overrideWithValue('DP-1'),
      screenForViewProvider(7).overrideWithValue('b'),
      monitorForScreenProvider('a').overrideWithValue('DP-1'),
    ]);
    final sub = container.listen(focusedScreenProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(platformFocusedViewIdProvider.notifier).set(7);
    expect(container.read(focusedScreenProvider), 'b');

    container.read(focusedScreenProvider.notifier).setFocusedScreen('a');
    expect(container.read(focusedScreenProvider), 'a');

    container.invalidate(focusedScreenProvider);
    expect(container.read(focusedScreenProvider), 'a');
  });

  test('a different focused monitor overrides the manual screen choice', () {
    final container = _container([
      screenManagerProvider.overrideWithValue(_manager({'a', 'b', 'c'})),
      monitorByViewIdProvider(7).overrideWithValue('DP-1'),
      monitorByViewIdProvider(8).overrideWithValue('DP-2'),
      screenForViewProvider(7).overrideWithValue('b'),
      screenForViewProvider(8).overrideWithValue('c'),
      monitorForScreenProvider('a').overrideWithValue('DP-1'),
    ]);
    final sub = container.listen(focusedScreenProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(platformFocusedViewIdProvider.notifier).set(7);
    container.read(focusedScreenProvider.notifier).setFocusedScreen('a');
    expect(container.read(focusedScreenProvider), 'a');

    container.read(platformFocusedViewIdProvider.notifier).set(8);

    expect(container.read(focusedScreenProvider), 'c');
  });

  test('without platform focus the first connected monitor is used', () {
    final container = _container([
      // Persisted order puts 'b' first; the compositor's first output (view 7)
      // renders 'a'.
      screenManagerProvider.overrideWithValue(_manager({'b', 'a'})),
      connectedMonitorListProvider.overrideWithValue([
        _monitor('DP-1', viewId: 7),
      ]),
      screenForViewProvider(7).overrideWithValue('a'),
    ]);

    expect(container.read(focusedScreenProvider), 'a');
  });

  test('platform focus waits for a known monitor, then follows it', () {
    final withLayout = _container([
      screenManagerProvider.overrideWithValue(_manager({'a'})),
      connectedMonitorListProvider.overrideWithValue([
        _monitor('DP-1', viewId: 7),
      ]),
      screenForViewProvider(7).overrideWithValue('a'),
      monitorByViewIdProvider(7).overrideWithValue('DP-1'),
    ]);
    final withoutLayout = _container([
      screenManagerProvider.overrideWithValue(_manager({'a'})),
    ]);

    // Nothing is focused until the layout is known, so a persisted fallback
    // can't pin the wrong monitor at startup.
    expect(withoutLayout.read(platformFocusedScreenProvider), isNull);
    // With the layout known the first connected monitor wins before any report.
    expect(withLayout.read(platformFocusedScreenProvider), 'a');

    withLayout.read(platformFocusedViewIdProvider.notifier).set(7);
    expect(withLayout.read(platformFocusedScreenProvider), 'a');
  });
}
