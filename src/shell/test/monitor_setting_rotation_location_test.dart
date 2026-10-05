import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';
import 'package:shell/settings/provider/state/monitor_setting_change_confirmation.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';
import 'package:shell/settings/provider/util/config_directory.dart';

const _mode = Mode(size: Size(1920, 1080), refreshRate: 60000);

Monitor _monitor() => Monitor(
  name: 'DP-1',
  description: 'DP-1 panel',
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
  viewId: 1,
);

Map<String, dynamic> _write(String dir, Map<String, dynamic> json) {
  File(
    '$dir/monitor/DP-1.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  return json;
}

Map<String, dynamic> _read(String dir) =>
    jsonDecode(File('$dir/monitor/DP-1.json').readAsStringSync())
        as Map<String, dynamic>;

/// Builds a container whose setting writes land in a fresh temp config dir,
/// with a very short confirmation timeout so rollback is observable.
(ProviderContainer, Directory) _container() {
  final temp = Directory.systemTemp.createTempSync('veshell_monitor_');
  Directory('${temp.path}/monitor').createSync();
  _write(temp.path, {
    'mode': _mode.toJson(),
    'fractionnalScale': 1.0,
    'location': {'x': 0, 'y': 0},
  });

  final container = ProviderContainer(
    overrides: [
      configDirectoryProvider.overrideWithValue(temp),
      connectedMonitorListProvider.overrideWithValue([_monitor()]),
      monitorSettingConfirmationTimeoutProvider.overrideWithValue(
        const Duration(milliseconds: 300),
      ),
    ],
  );
  // Keep the auto-dispose setting state alive, as the monitor views do.
  container.listen(monitorSettingStateProvider('DP-1'), (_, _) {});
  return (container, temp);
}

void main() {
  test('moving during a pending rotation survives the rollback', () async {
    final (container, temp) = _container();
    addTearDown(container.dispose);
    addTearDown(() => temp.deleteSync(recursive: true));

    final notifier = container.read(
      monitorSettingStateProvider('DP-1').notifier,
    );

    notifier.setTransform(MonitorTransform.rotate90);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    notifier.setLocation(const Offset(1000, 0));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Let the (unconfirmed) rotation time out and roll back.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final json = _read(temp.path);
    expect(json['transform'], 'normal');
    // The move was not part of the guarded change and must be preserved.
    expect(json['location'], {'x': 1000, 'y': 0});
  });

  test('rotating after a move keeps the moved location', () async {
    final (container, temp) = _container();
    addTearDown(container.dispose);
    addTearDown(() => temp.deleteSync(recursive: true));

    final notifier = container.read(
      monitorSettingStateProvider('DP-1').notifier,
    );

    notifier.setLocation(const Offset(1000, 0));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    notifier.setTransform(MonitorTransform.rotate90);
    // Accept the rotation so only the "rotate" write is under test.
    container.read(monitorSettingChangeConfirmationProvider.notifier).confirm();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final json = _read(temp.path);
    expect(json['transform'], 'rotate90');
    expect(json['location'], {'x': 1000, 'y': 0});
  });

  test('back-to-back move and rotate keep both', () async {
    final (container, temp) = _container();
    addTearDown(container.dispose);
    addTearDown(() => temp.deleteSync(recursive: true));

    final notifier = container.read(
      monitorSettingStateProvider('DP-1').notifier,
    );

    notifier.setLocation(const Offset(1000, 0));
    notifier.setTransform(MonitorTransform.rotate90);
    container.read(monitorSettingChangeConfirmationProvider.notifier).confirm();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final json = _read(temp.path);
    expect(json['transform'], 'rotate90');
    expect(json['location'], {'x': 1000, 'y': 0});
  });
}
