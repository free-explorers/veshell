import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/notification/provider/system_notification_manager.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_battery_device.dart';
import 'package:shell/settings/provider/state/battery_threshold_setting.dart';
import 'package:upower/upower.dart';

part 'battery_notification.g.dart';

/// Which battery warning a sample warrants, if any.
enum BatteryWarning { none, low, critical }

/// Pure decision: given the battery power state and the already-raised flags,
/// returns the warning this sample should raise.
///
/// A discharge warns once per level: the caller sets the `*Warned` flags and
/// clears them when the battery charges back up. UPower's own `warningLevel` is
/// honored alongside the configured percentage thresholds, so a device that
/// reports `critical` early (or whose percentage is unreliable) still warns.
BatteryWarning nextBatteryWarning({
  required UPowerDeviceState state,
  required UPowerDeviceWarningLevel warningLevel,
  required double percentage,
  required int lowThreshold,
  required int criticalThreshold,
  required bool lowWarned,
  required bool criticalWarned,
}) {
  if (!isDischarging(state)) {
    return BatteryWarning.none;
  }
  final atCritical =
      warningLevel == UPowerDeviceWarningLevel.critical ||
      warningLevel == UPowerDeviceWarningLevel.action ||
      percentage <= criticalThreshold;
  if (atCritical && !criticalWarned) {
    return BatteryWarning.critical;
  }
  final atLow =
      warningLevel == UPowerDeviceWarningLevel.low ||
      percentage <= lowThreshold;
  if (atLow && !lowWarned) {
    return BatteryWarning.low;
  }
  return BatteryWarning.none;
}

/// Whether a `UPowerDeviceState` represents the battery draining.
bool isDischarging(UPowerDeviceState state) =>
    state == UPowerDeviceState.discharging ||
    state == UPowerDeviceState.pendingDischarge;

/// Watches the system battery and raises a transient warning when it crosses
/// the configured low/critical thresholds (or when UPower itself raises them),
/// once per discharge cycle.
@Riverpod(keepAlive: true)
class BatteryNotification extends _$BatteryNotification {
  bool _lowWarned = false;
  bool _criticalWarned = false;

  @override
  void build() {
    final device = ref.watch(upowerBatteryDeviceProvider).value;
    final lowThreshold = ref.watch(batteryLowThresholdSettingProvider);
    final criticalThreshold = ref.watch(
      batteryCriticalThresholdSettingProvider,
    );
    if (device == null) {
      return;
    }
    final subscription = device.propertiesChanged.listen((_) {
      _evaluate(device, lowThreshold, criticalThreshold);
    });
    ref.onDispose(subscription.cancel);
    _evaluate(device, lowThreshold, criticalThreshold);
  }

  void _evaluate(UPowerDevice device, int lowThreshold, int criticalThreshold) {
    try {
      final warning = nextBatteryWarning(
        state: device.state,
        warningLevel: _warningLevel(device),
        percentage: device.percentage,
        lowThreshold: lowThreshold,
        criticalThreshold: criticalThreshold,
        lowWarned: _lowWarned,
        criticalWarned: _criticalWarned,
      );
      if (warning == BatteryWarning.none) {
        // Charging clears the cycle so the next discharge warns again. A
        // battery that merely hovers above the threshold keeps its flags, so it
        // does not re-warn on every sample.
        if (!isDischarging(device.state)) {
          _lowWarned = false;
          _criticalWarned = false;
        }
        return;
      }
      if (warning == BatteryWarning.critical) {
        _criticalWarned = true;
        _lowWarned = true;
        ref
            .read(systemNotificationManagerProvider.notifier)
            .showBattery(percentage: device.percentage, isCritical: true);
      } else {
        _lowWarned = true;
        ref
            .read(systemNotificationManagerProvider.notifier)
            .showBattery(percentage: device.percentage, isCritical: false);
      }
    } on Object catch (_) {
      // A device whose properties are not fully populated yet must not kill the
      // change stream; the next sample is evaluated normally.
    }
  }

  /// UPower's `WarningLevel`, defaulting to `unknown` when the property is
  /// absent on the connected device.
  UPowerDeviceWarningLevel _warningLevel(UPowerDevice device) {
    try {
      return device.warningLevel;
    } on Object catch (_) {
      return UPowerDeviceWarningLevel.unknown;
    }
  }
}
