import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:shell/monitor/provider/monitor_by_view_id.dart';
import 'package:shell/monitor/provider/platform_focused_view.dart';
import 'package:shell/screen/model/screen_manager_state.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/monitor_for_screen.dart';
import 'package:shell/screen/provider/screen_for_view.dart';
import 'package:shell/screen/provider/screen_manager.dart';

ScreenManagerState _manager(Set<String> screenIds) =>
    ScreenManagerState(screenIds: screenIds.lock);

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
}
