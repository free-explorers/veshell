import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/provider/dbus_client.dart';
import 'package:shell/shared/util/file.dart';
import 'package:shell/shared/util/logger.dart';

part 'session_guard.g.dart';

/// `org.freedesktop.login1.Manager.PrepareForShutdown` as a stream of booleans.
///
/// `true` means a shutdown/reboot is being prepared, `false` means it was
/// cancelled. Kept separate from [SessionGuard] so tests can drive the signal
/// without a system bus.
@Riverpod(keepAlive: true)
Stream<bool> prepareForShutdownSignals(Ref ref) {
  final client = ref.watch(dbusClientProvider);
  final login1 = DBusRemoteObject(
    client,
    name: 'org.freedesktop.login1',
    path: DBusObjectPath('/org/freedesktop/login1'),
  );

  final signals = DBusRemoteObjectSignalStream(
    object: login1,
    interface: 'org.freedesktop.login1.Manager',
    name: 'PrepareForShutdown',
    signature: DBusSignature('b'),
  );

  return signals.map((signal) => signal.values.first.asBoolean()).handleError((
    Object error,
    StackTrace stackTrace,
  ) {
    persistenceLog.warning(
      'PrepareForShutdown subscription failed',
      error,
      stackTrace,
    );
  });
}

/// Guards persisted state while the session is leaving.
///
/// A shutdown terminates applications before/while they report their windows
/// gone. Those teardown events must not overwrite the last complete state the
/// user wants to resume, so every window-state writer checks [isLeaving] and
/// the session controls flush pending debounced writes before asking logind to
/// end the session.
///
/// The `PrepareForShutdown` subscription also covers external shutdowns
/// (`systemctl reboot`, the power button), which never pass through the shell's
/// session controls.
@Riverpod(keepAlive: true)
class SessionGuard extends _$SessionGuard {
  bool _isLeaving = false;

  /// Whether the session is shutting down, rebooting or logging out.
  bool get isLeaving => _isLeaving;

  @override
  void build() {
    // Watching (rather than only listening) is what activates the stream
    // provider; this notifier is the only consumer.
    final signal = ref.watch(prepareForShutdownSignalsProvider);
    final active = signal.value;
    if (active == null) {
      return;
    }
    if (active) {
      unawaited(beginLeaving());
    } else {
      // Shutdown/reboot was cancelled (polkit denial, inhibitor, ...).
      cancelLeaving();
    }
  }

  /// Marks the session as leaving and flushes pending writes.
  ///
  /// The flag is set synchronously, before the first await, so window removal
  /// events that arrive while the flush runs are already suppressed.
  Future<void> beginLeaving() async {
    _isLeaving = true;
    await flushPendingWrites();
  }

  /// Clears the leaving flag when a shutdown attempt is cancelled or fails.
  void cancelLeaving() {
    _isLeaving = false;
  }

  /// Flushes state before a suspend/hibernate, which keeps the shell alive and
  /// therefore must not latch the teardown guard.
  Future<void> flushBeforeSuspend() => flushPendingWrites();
}
