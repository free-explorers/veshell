/// Reasons carried by the D-Bus `NotificationClosed` signal.
///
/// The numeric values are fixed by the Desktop Notifications spec.
enum NotificationCloseReason {
  /// The notification expired (reason 1).
  expired(1),

  /// The user dismissed the notification (reason 2). Also used when an action
  /// closes a non-resident notification.
  dismissed(2),

  /// A client called `CloseNotification` (reason 3).
  closedByCall(3);

  const NotificationCloseReason(this.value);

  /// The reason as sent on the wire.
  final int value;
}
