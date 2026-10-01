import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shell/shared/util/logger.dart';

/// How often the monitoring cards refresh. Shared so every metric samples on
/// the same cadence.
const monitoringSampleInterval = Duration(milliseconds: 500);

int? _pageSize;

/// System page size in bytes, resolved once.
///
/// Spawning `getconf` on every sample would block the UI isolate, and the page
/// size never changes while the process runs.
int get systemPageSize => _pageSize ??= _resolvePageSize();

int _resolvePageSize() {
  try {
    final result = Process.runSync('getconf', ['PAGESIZE']);
    return int.tryParse((result.stdout as String).trim()) ?? 4096;
  } on Exception {
    return 4096;
  }
}

/// Numeric PIDs currently present under `/proc`.
Future<List<int>> listProcessIds() async {
  final ids = <int>[];
  try {
    await for (final entity in Directory('/proc').list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = int.tryParse(p.basename(entity.path));
      if (id != null) ids.add(id);
    }
  } on Exception {
    // `/proc` is always mounted; a transient failure just yields no rows.
  }
  return ids;
}

/// Reads a `/proc` or `/sys` file, or returns `null` when it is unreadable.
///
/// Processes routinely exit between the directory listing and the read, and
/// sysfs attributes come and go with the hardware, so a missing file is an
/// expected race, not an error.
Future<String?> readTextFile(String path) async {
  try {
    return await File(path).readAsString();
  } on Exception {
    return null;
  }
}

/// Whether [pid] is a kernel thread.
///
/// Kernel threads have no executable behind `/proc/<pid>/exe`, unlike user
/// processes. The per-process lists drop them so they stay focused on
/// applications.
bool isKernelThread(int pid) {
  try {
    return !Link('/proc/$pid/exe').existsSync();
  } on FileSystemException {
    return true;
  }
}

/// Samples once immediately, then every [interval], until the returned callback
/// is invoked.
///
/// Sampling before the first interval matters for a freshly opened panel: an
/// auto-disposed provider rebuilds empty, so waiting a full interval would show
/// a blank card (seconds, for the disk scan). The next tick is scheduled only
/// after the current sample completes, so a slow scan cannot overlap the
/// following one; a thrown error is logged and swallowed rather than killing
/// the loop.
void Function() startPolling(
  Duration interval,
  Future<void> Function() sample,
) {
  var cancelled = false;
  Timer? timer;

  void schedule(Duration delay) {
    timer = Timer(delay, () async {
      if (cancelled) return;
      try {
        await sample();
      } on Object catch (error, stackTrace) {
        monitoringLog.warning('monitoring sample failed', error, stackTrace);
      }
      if (!cancelled) schedule(interval);
    });
  }

  schedule(Duration.zero);
  return () {
    cancelled = true;
    timer?.cancel();
  };
}
