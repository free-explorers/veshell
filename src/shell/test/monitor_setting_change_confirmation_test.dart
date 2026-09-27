import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';
import 'package:shell/settings/provider/state/monitor_setting_change_confirmation.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';

/// Records desired-geometry writes instead of touching the config directory.
class _FakeMonitorSettingState extends MonitorSettingState {
  final writes = <Map<String, dynamic>>[];

  @override
  MonitorSetting build(String monitorId) => MonitorSetting(
    mode: const Mode(size: Size(1920, 1080), refreshRate: 60000),
    fractionnalScale: 1,
    location: Offset.zero,
  );

  @override
  Future<void> updateFile(Map<String, dynamic> json) async {
    writes.add(json);
  }
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    monitorSettingStateProvider.overrideWith(_FakeMonitorSettingState.new),
    monitorSettingConfirmationTimeoutProvider.overrideWithValue(
      const Duration(milliseconds: 20),
    ),
  ],
);

_FakeMonitorSettingState _fakeFor(ProviderContainer container) {
  // Keep the (auto-dispose) setting state alive, as the monitor views do in
  // the shell, so the rollback write reaches the same notifier instance.
  container.listen(monitorSettingStateProvider('DP-1'), (_, __) {});
  return container.read(monitorSettingStateProvider('DP-1').notifier)
      as _FakeMonitorSettingState;
}

void main() {
  test('applies the change immediately and rolls it back on timeout', () {
    fakeAsync((async) {
      final container = _container();
      final fake = _fakeFor(container);
      final notifier = container.read(
        monitorSettingChangeConfirmationProvider.notifier,
      );
      expect(
        container.read(monitorSettingConfirmationTimeoutProvider),
        const Duration(milliseconds: 20),
      );

      notifier.propose(
        monitorId: 'DP-1',
        description: 'Transform of DP-1',
        previous: {'transform': 'normal'},
        next: {'transform': 'rotate90'},
      );

      expect(fake.writes, [
        {'transform': 'rotate90'},
      ]);
      expect(
        container.read(monitorSettingChangeConfirmationProvider),
        isNotNull,
      );

      async.elapse(const Duration(milliseconds: 30));

      expect(fake.writes, [
        {'transform': 'rotate90'},
        {'transform': 'normal'},
      ]);
      expect(container.read(monitorSettingChangeConfirmationProvider), isNull);
      container.dispose();
    });
  });

  test('keeps the change when confirmed before the timeout', () {
    fakeAsync((async) {
      final container = _container();
      final fake = _fakeFor(container);
      final notifier = container.read(
        monitorSettingChangeConfirmationProvider.notifier,
      );

      notifier.propose(
        monitorId: 'DP-1',
        description: 'Transform of DP-1',
        previous: {'transform': 'normal'},
        next: {'transform': 'rotate90'},
      );
      notifier.confirm();

      async.elapse(const Duration(milliseconds: 30));

      expect(fake.writes, [
        {'transform': 'rotate90'},
      ]);
      expect(container.read(monitorSettingChangeConfirmationProvider), isNull);
      container.dispose();
    });
  });

  test('a follow-up change keeps the original baseline', () {
    fakeAsync((async) {
      final container = _container();
      final fake = _fakeFor(container);
      final notifier = container.read(
        monitorSettingChangeConfirmationProvider.notifier,
      );

      notifier.propose(
        monitorId: 'DP-1',
        description: 'Transform of DP-1',
        previous: {'transform': 'normal'},
        next: {'transform': 'rotate90'},
      );
      notifier.propose(
        monitorId: 'DP-1',
        description: 'Transform of DP-1',
        previous: {'transform': 'rotate90'},
        next: {'transform': 'rotate180'},
      );

      expect(fake.writes, [
        {'transform': 'rotate90'},
        {'transform': 'rotate180'},
      ]);

      async.elapse(const Duration(milliseconds: 30));

      // Rollback returns to the last confirmed state, not the intermediate one.
      expect(fake.writes.last, {'transform': 'normal'});
      container.dispose();
    });
  });
}
