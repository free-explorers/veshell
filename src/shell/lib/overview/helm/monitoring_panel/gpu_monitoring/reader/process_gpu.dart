import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/drm_fdinfo.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

/// One walk of a [GpuDevice]'s DRM clients.
class DeviceEngineSample {
  /// Creates a sample.
  const DeviceEngineSample(
    this.processNanoseconds,
    this.clientEngines, {
    required this.hasEngineCounters,
  });

  /// Per-pid total engine nanoseconds.
  final Map<int, int> processNanoseconds;

  /// Engine nanoseconds per `drm-client-id`, then per engine.
  final Map<int, Map<String, int>> clientEngines;

  /// Whether the clients reported `drm-engine-*` counters at all.
  ///
  /// Xe reports `drm-cycles-*` instead, so an empty [clientEngines] is not the
  /// same as an idle GPU.
  final bool hasEngineCounters;
}

/// Walks [device]'s clients on a short-lived isolate, off the UI isolate.
///
/// Used by the expanded GPU card's process list on vendors other than Intel;
/// on Intel the monitoring sampler's walk serves the card and the list.
Future<DeviceEngineSample> sampleDevice(GpuDevice device) =>
    Isolate.run(() => walkDeviceClients(device));

/// Walks `/proc` for [device]'s clients.
///
/// Synchronous, and only ever run off the UI isolate (the monitoring sampler,
/// or [sampleDevice]'s `Isolate.run`): blocking reads of `/proc` cost one
/// system call each, where asynchronous ones would wake an IO thread several
/// times per file.
DeviceEngineSample walkDeviceClients(GpuDevice device) {
  final processNanoseconds = <int, int>{};
  final clientEngines = <int, Map<String, int>>{};
  final seenClients = <int>{};
  final seenPerPid = <int, Set<int>>{};
  var hasEngineCounters = false;

  final pids = listProcessIdsSync();
  for (final pid in pids) {
    final fdDirectory = Directory('/proc/$pid/fd');
    List<FileSystemEntity> fds;
    try {
      fds = fdDirectory.listSync(followLinks: false);
    } on FileSystemException {
      continue; // The process exited between listing and opening its fds.
    }

    for (final fd in fds) {
      final name = p.basename(fd.path);
      if (int.tryParse(name) == null) continue;

      final String target;
      try {
        target = Link(fd.path).targetSync();
      } on FileSystemException {
        continue;
      }
      if (!target.contains('/dev/dri/')) continue;

      final contents = readTextFileSync('/proc/$pid/fdinfo/$name');
      if (contents == null) continue;
      final info = parseDrmFdInfo(contents);
      if (info == null) continue;
      final pciAddress = device.pciAddress;
      if (pciAddress != null) {
        if (info.cardPciAddress != pciAddress) continue;
      } else if (info.driver != device.driver) {
        // Without a PCI address fall back to the driver, so a second card of
        // the same driver may still be attributed here.
        continue;
      }

      if (info.engineNanoseconds.isNotEmpty) hasEngineCounters = true;
      final clientId = info.clientId;
      if (clientId == null) {
        // No client id to key the per-client deltas on: still attribute the
        // time to its process.
        processNanoseconds[pid] =
            (processNanoseconds[pid] ?? 0) + info.totalEngineNanoseconds;
        continue;
      }
      if (seenClients.add(clientId)) {
        final engines = clientEngines.putIfAbsent(
          clientId,
          () => <String, int>{},
        );
        info.engineNanoseconds.forEach((engine, nanoseconds) {
          engines[engine] = (engines[engine] ?? 0) + nanoseconds;
        });
      }
      final perPid = seenPerPid.putIfAbsent(pid, () => <int>{});
      if (perPid.add(clientId)) {
        processNanoseconds[pid] =
            (processNanoseconds[pid] ?? 0) + info.totalEngineNanoseconds;
      }
    }
  }

  processNanoseconds.removeWhere((_, nanoseconds) => nanoseconds <= 0);
  return DeviceEngineSample(
    processNanoseconds,
    clientEngines,
    hasEngineCounters: hasEngineCounters,
  );
}
