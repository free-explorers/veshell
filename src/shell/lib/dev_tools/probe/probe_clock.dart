import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';

/// How long a frozen clock waits for the probe before it resumes on its own:
/// a probe that died must not leave the shell frozen.
const probeClockLease = Duration(seconds: 30);

/// The animation time the shell's frames carry, as `veshell-probe` sets it:
/// running (the engine's time, continuous across a freeze), frozen at an
/// instant, or stepped from that instant by exact amounts.
///
/// Every frame still runs while frozen, so layout and paint follow the
/// state; only the time animations see stands still. A step moves it by the
/// exact amount asked, whatever the machine's speed: frame `k` of a capture
/// shows exactly `k` steps.
class ProbeClockTime {
  Duration? _frozenAt;
  Duration _offset = Duration.zero;
  Duration? _lastDelivered;
  bool _resuming = false;

  bool get isFrozen => _frozenAt != null;

  /// The time the last frame carried.
  Duration? get lastDelivered => _lastDelivered;

  /// The time to give the frame the engine stamped [raw].
  Duration timeFor(Duration raw) {
    if (_resuming) {
      // Continue from the frozen instant: no jump, no time going back.
      _offset = raw - _frozenAt!;
      _frozenAt = null;
      _resuming = false;
    }
    final time = _frozenAt ?? raw - _offset;
    _lastDelivered = time;
    return time;
  }

  /// Stops the time at the last frame's.
  void freeze() {
    if (isFrozen) {
      // Still frozen (a resume not yet applied is just cancelled): keep the
      // instant the time stands at.
      _resuming = false;
      return;
    }
    _frozenAt = _lastDelivered ?? Duration.zero;
  }

  /// Moves the frozen time forward by [by]; returns the new time.
  Duration step(Duration by) {
    if (!isFrozen || _resuming) {
      freeze();
    }
    return _frozenAt = _frozenAt! + by;
  }

  /// Lets the time run again, from where it stands, on the next frame.
  void resume() {
    if (isFrozen) {
      _resuming = true;
    }
  }
}

/// Puts [ProbeClockTime] between the engine and the scheduler: frames keep
/// coming from the engine, with the time the probe sets.
class ProbeClock {
  ProbeClock._();

  static final ProbeClock instance = ProbeClock._();

  final ProbeClockTime time = ProbeClockTime();
  ui.FrameCallback? _engineBeginFrame;
  Timer? _lease;

  void _install() {
    if (_engineBeginFrame != null) {
      return;
    }
    final dispatcher = ui.PlatformDispatcher.instance;
    final scheduler = dispatcher.onBeginFrame;
    if (scheduler == null) {
      throw StateError('The scheduler has not registered its frame callback');
    }
    _engineBeginFrame = scheduler;
    dispatcher.onBeginFrame = (raw) => scheduler(time.timeFor(raw));
  }

  void _renewLease() {
    _lease?.cancel();
    _lease = Timer(probeClockLease, resume);
  }

  /// Freezes animation time at the last frame's.
  Future<Map<String, Object?>> freeze() async {
    _install();
    time.freeze();
    _renewLease();
    return status();
  }

  /// Moves frozen animation time forward by [by] and waits for the frame
  /// showing it to be drawn.
  Future<Map<String, Object?>> step(Duration by) async {
    _install();
    time.step(by);
    _renewLease();
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 1),
      onTimeout: () {},
    );
    return status();
  }

  /// Lets animation time run again.
  Map<String, Object?> resume() {
    _lease?.cancel();
    _lease = null;
    time.resume();
    if (_engineBeginFrame != null) {
      SchedulerBinding.instance.scheduleFrame();
    }
    return status();
  }

  Map<String, Object?> status() => {
    'frozen': time.isFrozen,
    'timeMicros': time.lastDelivered?.inMicroseconds,
    'timeDilation': timeDilation,
  };
}
