import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';

part 'monitor_setting_change_confirmation.g.dart';

/// A monitor settings change that is applied but not yet confirmed.
@immutable
class MonitorSettingChange {
  const MonitorSettingChange({
    required this.monitorId,
    required this.description,
    required this.previous,
    required this.next,
    required this.deadline,
  });

  /// Monitor the change applies to.
  final MonitorId monitorId;

  /// Short human-readable description of what changed.
  final String description;

  /// Last confirmed guarded fields, restored on rollback.
  final Map<String, dynamic> previous;

  /// Just-applied desired geometry, kept on confirmation.
  final Map<String, dynamic> next;

  /// When the change is rolled back if not confirmed.
  final DateTime deadline;
}

/// How long the user has to confirm a display change before it is rolled back.
@riverpod
Duration monitorSettingConfirmationTimeout(Ref ref) =>
    const Duration(seconds: 15);

/// Guards risky monitor settings changes (mode, scale, transform).
///
/// A change is applied immediately and rolled back to the last confirmed state
/// unless the user keeps it before [monitorSettingConfirmationTimeout]. Kept
/// alive so the rollback timer survives view rebuilds and still fires when the
/// changed monitor itself is unusable.
///
/// Rollback only reverts the guarded fields: location and mirroring are written
/// directly and are preserved. See `docs/specifications/monitor.md` (section
/// "Change confirmation").
///
/// Only one change is guarded at a time. This is enforced, not assumed: while a
/// change is pending the confirmation overlay is the only interactive surface
/// (it blocks both pointer and keyboard input on every monitor), so no second
/// guarded change can be started through the UI.
@Riverpod(keepAlive: true)
class MonitorSettingChangeConfirmation
    extends _$MonitorSettingChangeConfirmation {
  Timer? _timer;

  @override
  MonitorSettingChange? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Applies [next] right away and starts the confirmation countdown.
  ///
  /// When a change for the same monitor is already pending, its original
  /// baseline is kept so a rollback always returns to the last confirmed
  /// state, and the countdown is restarted.
  void propose({
    required MonitorId monitorId,
    required String description,
    required Map<String, dynamic> previous,
    required Map<String, dynamic> next,
  }) {
    final timeout = ref.read(monitorSettingConfirmationTimeoutProvider);
    final baseline = state != null && state!.monitorId == monitorId
        ? state!.previous
        : previous;
    state = MonitorSettingChange(
      monitorId: monitorId,
      description: description,
      previous: baseline,
      next: next,
      deadline: DateTime.now().add(timeout),
    );
    _write(monitorId, next);
    _timer?.cancel();
    _timer = Timer(timeout, rollback);
  }

  /// The user accepted the change: keep it.
  void confirm() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }

  /// Discard the change and restore the last confirmed guarded fields, keeping
  /// the current location and mirror target.
  ///
  /// Only the guarded fields (mode, scale, transform) are restored, so a
  /// location or mirror edit made while the change was pending is not lost.
  void rollback() {
    final pending = state;
    _timer?.cancel();
    _timer = null;
    state = null;
    if (pending != null) {
      ref
          .read(monitorSettingStateProvider(pending.monitorId).notifier)
          .restoreGuarded(pending.previous);
    }
  }

  void _write(MonitorId monitorId, Map<String, dynamic> json) {
    unawaited(
      ref
          .read(monitorSettingStateProvider(monitorId).notifier)
          .updateFile(json),
    );
  }
}
