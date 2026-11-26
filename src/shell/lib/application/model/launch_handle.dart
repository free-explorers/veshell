import 'dart:async';
import 'dart:io';

import 'package:shell/application/model/launch_scope_tracker.dart';

/// Something that happened to a launch after it started.
sealed class LaunchEvent {
  const LaunchEvent();
}

/// The launch process exited.
///
/// The process is the `systemd-run --wait` supervisor of the launch's unit,
/// which exits once the unit's whole cgroup is empty. A clean exit before the
/// application showed a window is therefore a hand-off, not an end: the
/// application went on elsewhere (`steam steam://rungameid/...` asked the
/// running client, `flatpak run` or Chromium moved it to a scope of its own).
final class LaunchExited extends LaunchEvent {
  const LaunchExited(this.exitCode);

  final int exitCode;

  bool get isClean => exitCode == 0;
}

/// The application appeared in the systemd unit it was expected to end up in
/// (see [ScopeIdentity]): it really started.
final class LaunchUnitStarted extends LaunchEvent {
  const LaunchUnitStarted(this.unit);

  /// The unit, relative to the user manager's `app.slice`.
  final String unit;
}

/// The unit the application started in is gone: its last process exited.
final class LaunchUnitEnded extends LaunchEvent {
  const LaunchUnitEnded(this.unit);

  /// The unit, relative to the user manager's `app.slice`.
  final String unit;
}

/// Starts following an application's unit, reporting to the callbacks.
typedef LaunchUnitFollower =
    LaunchScopeTracker? Function(
      void Function(String unit) onStarted,
      void Function(String unit) onEnded,
    );

/// A launch in flight: its process, and what happens to it afterwards.
///
/// [events] is buffered until it is listened to, so nothing that happens
/// between the launch and the caller's subscription is lost.
class LaunchHandle {
  LaunchHandle({
    required this.process,
    this.carriedOutBy,
    LaunchUnitFollower? followUnit,
  }) {
    _tracker = followUnit?.call(
      (unit) => _emit(LaunchUnitStarted(unit)),
      (unit) => _emit(LaunchUnitEnded(unit)),
    );
    unawaited(
      process.exitCode.then((exitCode) {
        if (exitCode != 0) {
          // The launch failed: whatever unit appears now is not this one's.
          _tracker?.cancel();
        }
        _emit(LaunchExited(exitCode));
      }),
    );
  }

  /// The launch process (the unit's supervisor, or the application itself
  /// without a systemd user manager): its pid keys the execution logs.
  final Process process;

  /// Desktop ids of the application that carries the launch out (Steam
  /// starting a game), or null when the tile's application runs it itself.
  final Set<String>? carriedOutBy;

  /// Whether another application carries the launch out, which may first
  /// have to start itself.
  bool get handsOff => carriedOutBy != null;

  LaunchScopeTracker? _tracker;
  final _events = StreamController<LaunchEvent>();
  bool _cancelled = false;

  Stream<LaunchEvent> get events => _events.stream;

  /// Whether the application's unit appeared.
  bool get unitStarted => _tracker?.scope != null;

  void _emit(LaunchEvent event) {
    if (!_cancelled) {
      _events.add(event);
    }
  }

  /// Stops following the launch. The application itself is left running.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _tracker?.cancel();
    unawaited(_events.close());
  }
}

/// The follower for [identity]'s unit under [slice], or null when there is
/// nothing to follow.
LaunchUnitFollower? followUnitIn(Directory? slice, ScopeIdentity? identity) {
  if (slice == null || identity == null) {
    return null;
  }
  return (onStarted, onEnded) => LaunchScopeTracker.watch(
    slice: slice,
    identity: identity,
    onStarted: onStarted,
    onEnded: onEnded,
  );
}
