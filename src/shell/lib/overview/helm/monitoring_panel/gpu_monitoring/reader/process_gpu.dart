import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/amdgpu.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/drm_fdinfo.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

/// Per-pid total GPU engine time, in nanoseconds, for clients of [device].
///
/// Scans `/proc/<pid>/fd` for descriptors pointing at `/dev/dri/` before
/// reading their `fdinfo`, which keeps the walk off the many non-DRM fds. Fds
/// that share a DRM client (a `dup`) are counted once. Processes with no client
/// on [device] are omitted; [GpuDevice.pciAddress] filters out other cards.
Future<Map<int, int>> sampleProcessEngineNanoseconds(GpuDevice device) async {
  final result = <int, int>{};
  final pids = await listProcessIds();
  for (final pid in pids) {
    final fdDirectory = Directory('/proc/$pid/fd');
    List<FileSystemEntity> fds;
    try {
      fds = fdDirectory.listSync(followLinks: false);
    } on FileSystemException {
      continue; // The process exited between listing and opening its fds.
    }

    final seenClients = <int>{};
    var totalNanoseconds = 0;
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

      final contents = await readTextFile('/proc/$pid/fdinfo/$name');
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

      final clientId = info.clientId;
      if (clientId != null && !seenClients.add(clientId)) continue;
      totalNanoseconds += info.totalEngineNanoseconds;
    }

    if (totalNanoseconds > 0) result[pid] = totalNanoseconds;
  }
  return result;
}
