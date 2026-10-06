import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/model/notification_hints.serializable.dart';
import 'package:shell/notification/model/system_notification_category.dart';
import 'package:shell/notification/provider/notification_channel.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/screen/provider/focused_screen.dart';

part 'system_notification_manager.g.dart';

/// The kind of a transient system notification. The kind is the identity used
/// to replace an earlier popup of the same kind instead of stacking (a held
/// volume key must not pile up one popup per step).
enum SystemNotificationKind { volume, brightness, batteryLow, batteryCritical }

/// How long a volume/brightness OSD stays on screen.
const systemOsdDuration = Duration(seconds: 2);

/// How long a low-battery warning stays on screen. A critical warning does not
/// expire on its own: it stays until dismissed (the D-Bus `0` timeout).
const systemBatteryLowDuration = Duration(seconds: 8);

/// Shows the shell's own transient notifications — volume, brightness and
/// battery — the same way a D-Bus notification is shown: as an anchored popup
/// that disappears on its own. They are synthesized (`isSynthetic`), so they
/// never enter the persisted notification history and emit no D-Bus signals.
///
/// Each [SystemNotificationKind] has a stable id, so re-showing the same kind
/// replaces the live popup in place. The popup is always pushed to the focused
/// screen's channel; if focus moved since the last popup, the previous one is
/// torn down first.
@Riverpod(keepAlive: true)
class SystemNotificationManager extends _$SystemNotificationManager {
  /// Channel currently hosting each kind's popup, so the previous popup can be
  /// torn down when the focused screen changes.
  final _popupChannelByKind = <SystemNotificationKind, String>{};

  /// Stable (negative) id per kind. Negative ids never collide with the
  /// positive ids `NotificationManager` assigns to real notifications.
  final _idByKind = <SystemNotificationKind, int>{};
  int _nextId = -1;

  @override
  void build() {
    final subscription = ref.watch(platformManagerProvider).listen(_onEvent);
    ref.onDispose(subscription.cancel);
  }

  void _onEvent(PlatformEvent event) {
    switch (event) {
      case BrightnessChangedEvent(:final message):
        showBrightness(message.fraction);
      default:
        break;
    }
  }

  /// Shows the current output volume. [muted] renders a muted icon and an empty
  /// bar; otherwise the bar follows [volume].
  void showVolume({required double volume, required bool muted}) {
    final percent = (volume.clamp(0.0, 1.0) * 100).round();
    _show(
      SystemNotificationKind.volume,
      summary: ref.read(shellLocalizationsProvider).volume,
      body: muted
          ? ref.read(shellLocalizationsProvider).muted
          : ref.read(shellLocalizationsProvider).percentValue(percent),
      category: muted ? systemVolumeMutedCategory : systemVolumeCategory,
      value: muted ? 0 : percent,
      timeout: systemOsdDuration,
    );
  }

  /// Shows the current display brightness as a fraction in `0.0..1.0`.
  void showBrightness(double fraction) {
    final percent = (fraction.clamp(0.0, 1.0) * 100).round();
    _show(
      SystemNotificationKind.brightness,
      summary: ref.read(shellLocalizationsProvider).brightness,
      body: ref.read(shellLocalizationsProvider).percentValue(percent),
      category: systemBrightnessCategory,
      value: percent,
      timeout: systemOsdDuration,
    );
  }

  /// Shows a battery warning. A critical warning does not auto-expire.
  void showBattery({required double percentage, required bool isCritical}) {
    final percent = percentage.clamp(0.0, 100.0).round();
    _show(
      isCritical
          ? SystemNotificationKind.batteryCritical
          : SystemNotificationKind.batteryLow,
      summary: isCritical
          ? ref.read(shellLocalizationsProvider).batteryCritical
          : ref.read(shellLocalizationsProvider).batteryLow,
      body: ref.read(shellLocalizationsProvider).batteryRemaining(percent),
      category: systemBatteryCategory,
      value: percent,
      timeout: isCritical ? null : systemBatteryLowDuration,
    );
  }

  void _show(
    SystemNotificationKind kind, {
    required String summary,
    required String body,
    required String category,
    required int value,
    required Duration? timeout,
  }) {
    final screenId = ref.read(focusedScreenProvider);
    if (screenId == null) {
      return;
    }
    final id = _idByKind.putIfAbsent(kind, () => _nextId--);
    final previousChannel = _popupChannelByKind[kind];
    if (previousChannel != null && previousChannel != screenId) {
      ref
          .read(notificationChannelProvider(previousChannel).notifier)
          .remove(id);
    }
    _popupChannelByKind[kind] = screenId;

    final notification = Notification(
      id: id,
      appId: null,
      dbusNotification: DbusNotification(
        pid: null,
        appName: ref.read(shellLocalizationsProvider).system,
        replacesId: 0,
        appIcon: '',
        summary: summary,
        body: body,
        actions: const [],
        hints: NotificationHints(category: category, value: value),
        expireTimeout: timeout?.inMilliseconds ?? 0,
      ),
      createdAt: DateTime.now(),
      isSynthetic: true,
    );
    ref
        .read(notificationChannelProvider(screenId).notifier)
        .add(
          notification,
          timeout: timeout,
          onExpire: () {
            if (_popupChannelByKind[kind] == screenId) {
              _popupChannelByKind.remove(kind);
            }
          },
        );
  }
}
