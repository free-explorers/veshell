import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/provider/process_info_state.dart';
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/systemd/provider/session_guard.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

part 'resume_context_recorder.g.dart';

/// How often a displayed tile's `/proc` facts are refreshed.
///
/// Window map/title changes capture immediately; this interval only covers
/// state that changes without a platform event (a terminal `cd`, a foreground
/// job starting or ending).
const _refreshInterval = Duration(seconds: 5);

/// Keeps each displayed tile's resume context in sync with its live process.
@riverpod
class ResumeContextRecorder extends _$ResumeContextRecorder {
  Timer? _timer;
  bool _polling = false;

  @override
  void build() {
    _timer = Timer.periodic(_refreshInterval, (_) => unawaited(_refresh()));
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
  }

  Future<void> _refresh() async {
    if (_polling) {
      return;
    }
    _polling = true;
    try {
      if (ref.read(sessionGuardProvider.notifier).isLeaving) {
        return;
      }
      final windowIds = ref
          .read(windowManagerProvider)
          .windows
          .whereType<PersistentWindowId>()
          .toList();
      for (final windowId in windowIds) {
        if (!ref.mounted) {
          return;
        }
        final tile = _tile(windowId);
        if (tile == null || tile.metaWindowId == null) {
          continue;
        }
        final pid = tile.properties.pid;
        if (pid == null || pid <= 0) {
          continue;
        }

        final info = await ref
            .read(platformManagerProvider.notifier)
            .fetchProcessInfo(pid);
        if (!ref.mounted) {
          return;
        }
        if (info == null) {
          continue;
        }
        ref.read(processInfoStateProvider.notifier).set(info);
        _capture(windowId, info);
      }
    } on Object catch (error, stackTrace) {
      matchingLog.warning('Resume-context refresh failed', error, stackTrace);
    } finally {
      _polling = false;
    }
  }

  PersistentWindow? _tile(PersistentWindowId windowId) {
    try {
      return ref.read(persistentWindowStateProvider(windowId));
    } on Object catch (error) {
      matchingLog.fine(
        'Resume poll skipped uninitialized tile $windowId: $error',
      );
      return null;
    }
  }

  void _capture(PersistentWindowId windowId, ProcessInfoMessage info) {
    try {
      ref
          .read(persistentWindowStateProvider(windowId).notifier)
          .captureResumeContext(info);
    } on Object catch (error) {
      matchingLog.fine('Resume capture failed for $windowId: $error');
    }
  }
}
