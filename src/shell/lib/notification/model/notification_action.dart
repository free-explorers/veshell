import 'package:flutter/foundation.dart';

/// The action key reserved by the Desktop Notifications spec for the implicit
/// "activate the notification" action, triggered by clicking the body.
const defaultNotificationActionKey = 'default';

/// A single action offered by a notification.
///
/// The D-Bus `Notify` call carries actions as a flat `[key, label, key,
/// label, …]` array. Each pair becomes one [NotificationAction].
@immutable
class NotificationAction {
  /// Const constructor.
  const NotificationAction({required this.key, required this.label});

  /// The key sent back in an `ActionInvoked` signal.
  final String key;

  /// Human-readable button label. Empty for the default action.
  final String label;

  /// Whether this is the implicit default action. It is invoked by clicking
  /// the notification body rather than a dedicated button.
  bool get isDefault => key == defaultNotificationActionKey;

  @override
  bool operator ==(Object other) =>
      other is NotificationAction && other.key == key && other.label == label;

  @override
  int get hashCode => Object.hash(key, label);
}

/// Parses the flat `actions` array from the Desktop Notifications spec.
///
/// A trailing key without a label is ignored, so a malformed payload never
/// throws. The default action ([NotificationAction.isDefault]) is kept.
List<NotificationAction> parseNotificationActions(List<String> raw) {
  final actions = <NotificationAction>[];
  for (var index = 0; index + 1 < raw.length; index += 2) {
    actions.add(NotificationAction(key: raw[index], label: raw[index + 1]));
  }
  return actions;
}

/// Returns the default action of [actions], or `null` when there is none.
NotificationAction? defaultNotificationAction(
  List<NotificationAction> actions,
) {
  for (final action in actions) {
    if (action.isDefault) {
      return action;
    }
  }
  return null;
}
