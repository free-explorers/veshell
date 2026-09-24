import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/provider/process_info_state.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_decision_recorder.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';

part 'platform_event_recorder.g.dart';

/// Directory where debug launch dumps are written.
final _recordsDirectory = Directory(
  '${Platform.environment['VESHELL_CONFIG_DIR']!}/matching-records',
);

/// Quiet period that ends the recording once the tile is matched. The timer is
/// re-armed on every event and every tile change, so a splash screen followed
/// by the real window keeps the recording alive, and a settled window ends it.
const _quietPeriod = Duration(seconds: 3);

/// Minimum recording time once matched. Covers sequential launches whose first
/// window (splash) matches well before the real window is created: the gap
/// between the two is silence, which would otherwise end the recording.
const _minRecordDuration = Duration(seconds: 8);

/// Hard stop so a failed launch still yields a dump.
const _recordingTimeout = Duration(seconds: 60);

/// Events that represent a real structural change and reset the settle window.
/// Per-frame `commit_surface` is deliberately not here: a busy application
/// commits continuously, which would otherwise keep the recording alive until
/// the hard timeout. Commit events are dropped from the dump entirely.
const _structuralEventMethods = <String>{
  'new_surface',
  'destroy_surface',
  'new_subsurface',
  'destroy_subsurface',
  'meta_window_created',
  'meta_window_patch',
  'meta_window_removed',
  'process_info',
  'set_environment_variables',
};

/// Records the compositor [PlatformEvent]s emitted around a debug launch,
/// from before the launch until the target persistent window is matched, at
/// least [_minRecordDuration] has elapsed, and the structural event stream has
/// been quiet for [_quietPeriod]. Per-frame `commit_surface` churn is omitted.
/// Writes the stream to a JSONL file (one `{ t, method, message }` per line),
/// bracketed by two synthetic records: a leading `_session` with the launching
/// tile and every tile sharing its app id, and a trailing `_process_info` with
/// the pid-keyed `/proc` facts (cgroup, Flatpak/Snap id, binary name).
///
/// The shell's matching decisions taken during the recording are interleaved
/// as `_matching` records (routing, candidate costs, fallbacks, dispatch moves
/// and dialog conversions), so the raw compositor events and the shell's
/// reaction to them share one timeline. See `MatchingDecision`.
///
/// Used by the placeholder's debug button to gather raw signal traces together
/// with the matching feedback they produced.
@Riverpod(keepAlive: true)
class PlatformEventRecorder extends _$PlatformEventRecorder {
  StreamSubscription<PlatformEvent>? _events;
  ProviderSubscription<PersistentWindow>? _target;
  void Function()? _decisionSubscription;
  Timer? _settleTimer;
  Timer? _timeoutTimer;
  final List<Map<String, Object?>> _buffer = [];
  Stopwatch? _stopwatch;
  PersistentWindowId? _targetWindowId;
  bool _matched = false;

  @override
  void build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      _target?.close();
      _settleTimer?.cancel();
      _timeoutTimer?.cancel();
    });
  }

  bool get isRecording => _stopwatch != null;

  /// (Re)starts the countdown to the end of the recording. Called on every
  /// event and tile change once the window is matched, so the dump only closes
  /// after the launch has actually settled.
  void _armSettle() {
    _settleTimer?.cancel();
    final elapsed = _stopwatch?.elapsed ?? Duration.zero;
    final remaining = _minRecordDuration - elapsed;
    _settleTimer = Timer(
      remaining > _quietPeriod ? remaining : _quietPeriod,
      stopAndDump,
    );
  }

  /// Starts recording, then launches [windowId] through the ordinary tracked
  /// launcher. Returns immediately; the dump is written by [stopAndDump] once
  /// the tile is matched and quiet, or after [_recordingTimeout].
  ///
  /// The launch happens regardless of whether recording could be set up, so a
  /// recorder failure never silently prevents the application from starting.
  void recordLaunch(PersistentWindowId windowId) {
    if (isRecording) {
      matchingLog.info(
        'A recording is already running; ignoring launch of ${windowId.uuid}',
      );
      return;
    }
    _startRecording(windowId);
    unawaited(
      ref.read(persistentWindowStateProvider(windowId).notifier).launchSelf(),
    );
  }

  void _startRecording(PersistentWindowId windowId) {
    _buffer.clear();
    _matched = false;
    _stopwatch = Stopwatch()..start();
    _targetWindowId = windowId;
    try {
      // Seed: the tile that launched, plus every tile sharing its app id,
      // since those are the placeholders the matcher may assign this launch's
      // surfaces to (parallel restores, several installs of one app).
      _buffer.add(_sessionHeader(windowId));

      _events = ref.read(platformManagerProvider).listen((event) {
        if (event.method == 'commit_surface') {
          return;
        }
        _buffer.add({
          't': _stopwatch?.elapsedMilliseconds,
          'method': event.method,
          'message': event.message.toJson(),
        });
        if (_matched && _structuralEventMethods.contains(event.method)) {
          _armSettle();
        }
      });

      // Matching decisions taken while the recording is active are appended to
      // the same buffer, so the raw compositor events and the shell's reaction
      // to them share one timeline.
      final decisionRecorder = ref.read(
        matchingDecisionRecorderProvider.notifier,
      );
      _decisionSubscription = decisionRecorder.listen((decision) {
        _buffer.add({
          't': _stopwatch?.elapsedMilliseconds,
          'method': '_matching',
          'message': decision.toJson(),
        });
      });
      decisionRecorder.start();

      _target = ref.listen<PersistentWindow>(
        persistentWindowStateProvider(windowId),
        (previous, next) {
          if (next.metaWindowId != null && !_matched) {
            _matched = true;
            matchingLog.info('Launch matched for tile ${windowId.uuid}');
            _armSettle();
          }
        },
      );
      final current = ref.read(persistentWindowStateProvider(windowId));
      if (current.metaWindowId != null) {
        _matched = true;
        _armSettle();
      }
      _timeoutTimer ??= Timer(_recordingTimeout, stopAndDump);

      matchingLog.info(
        'Recording platform events for launch on tile ${windowId.uuid} '
        '(appId="${current.properties.appId}")',
      );
    } on Object catch (error, stackTrace) {
      matchingLog.severe(
        'Failed to start platform event recording; launching anyway',
        error,
        stackTrace,
      );
      _reset();
    }
  }

  /// Clears recording state and subscriptions without writing a dump.
  void _reset() {
    _stopwatch = null;
    _matched = false;
    _settleTimer?.cancel();
    _settleTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    unawaited(_events?.cancel());
    _events = null;
    _target?.close();
    _target = null;
    _stopDecisionRecording();
    _targetWindowId = null;
  }

  /// Stops collecting matching decisions and unregisters the listener.
  void _stopDecisionRecording() {
    ref.read(matchingDecisionRecorderProvider.notifier).stop();
    _decisionSubscription?.call();
    _decisionSubscription = null;
  }

  /// First record of a dump: the tile that launched, plus every persistent
  /// tile sharing its app id — the placeholders the matcher may assign this
  /// launch's surfaces to (parallel restores, several installs of one app).
  ///
  /// Best-effort by design: the target tile is always present, but a peer tile
  /// whose state cannot be read (e.g. a window id left in the manager without
  /// a state file) is skipped rather than aborting the recording.
  Map<String, Object?> _sessionHeader(PersistentWindowId targetWindowId) {
    final target = ref.read(persistentWindowStateProvider(targetWindowId));
    final appId = target.properties.appId;
    final tiles = <Map<String, Object?>>[
      _tileSummary(target, isTarget: true),
    ];
    for (final windowId in _peerWindowIds(targetWindowId)) {
      try {
        final window = ref.read(persistentWindowStateProvider(windowId));
        if (window.properties.appId != appId) continue;
        tiles.add(_tileSummary(window, isTarget: false));
      } on Object catch (error) {
        matchingLog.warning(
          'Skipping tile ${windowId.uuid} in session header: $error',
        );
      }
    }
    return {
      't': 0,
      'method': '_session',
      'message': {
        'targetWindowId': targetWindowId.uuid,
        'appId': appId,
        'tiles': tiles,
      },
    };
  }

  /// Persistent tile ids known to the window manager, excluding the target.
  Iterable<PersistentWindowId> _peerWindowIds(
    PersistentWindowId targetWindowId,
  ) sync* {
    try {
      for (final windowId in ref.read(windowManagerProvider).windows) {
        if (windowId is PersistentWindowId &&
            windowId.uuid != targetWindowId.uuid) {
          yield windowId;
        }
      }
    } on Object catch (error) {
      matchingLog.warning('Cannot list peer tiles for session header: $error');
    }
  }

  Map<String, Object?> _tileSummary(
    PersistentWindow window, {
    required bool isTarget,
  }) {
    Object? workspaceId;
    try {
      workspaceId = ref.read(windowWorkspaceMapProvider).get(window.windowId);
    } on Object catch (_) {
      workspaceId = null;
    }
    return {
      'windowId': window.windowId.uuid,
      'isTarget': isTarget,
      'appId': window.properties.appId,
      'title': window.properties.title,
      'windowClass': window.properties.windowClass,
      'startupId': window.properties.startupId,
      'displayMode': window.displayMode.name,
      'customExec': window.customExec,
      'workspaceId': workspaceId,
      'metaWindowId': window.metaWindowId,
      'isWaitingForSurface': window.isWaitingForSurface,
      'pid': window.pid,
    };
  }

  /// Stops an active recording and writes the buffered events to disk.
  Future<void> stopAndDump() async {
    final stopwatch = _stopwatch;
    if (stopwatch == null) return;

    stopwatch.stop();
    _stopwatch = null;
    _settleTimer?.cancel();
    _settleTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    await _events?.cancel();
    _events = null;
    _target?.close();
    _target = null;
    _stopDecisionRecording();

    final windowId = _targetWindowId;
    _targetWindowId = null;
    final appId = windowId == null
        ? 'unknown'
        : ref.read(persistentWindowStateProvider(windowId)).properties.appId;

    // The `process_info` events already carry the `/proc` facts, but a final
    // snapshot makes the dump self-contained and easy to read.
    final processInfo = ref.read(processInfoStateProvider);
    if (processInfo.isNotEmpty) {
      _buffer.add({
        't': stopwatch.elapsedMilliseconds,
        'method': '_process_info',
        'message': {
          for (final entry in processInfo.entries)
            entry.key.toString(): entry.value.toJson(),
        },
      });
    }

    await _recordsDirectory.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(
      path.join(_recordsDirectory.path, 'launch-$appId-$stamp.jsonl'),
    );
    final dump = _buffer.map(jsonEncode).join('\n');
    await file.writeAsString('$dump\n');
    matchingLog.info(
      'Platform event dump (${_buffer.length} events): ${file.path}',
    );
  }
}
