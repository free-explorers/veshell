import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/drm_fdinfo.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

/// Per-pid total GPU engine time, in nanoseconds, for clients of [device].
///
/// Fds that share a DRM client (a `dup`) are counted once. Processes with no
/// client on [device] are omitted; [GpuDevice.pciAddress] filters out other
/// cards.
Future<Map<int, int>> sampleProcessEngineNanoseconds(GpuDevice device) async {
  final result = <int, int>{};
  await _forEachClient(device, (pid, info) {
    result[pid] = (result[pid] ?? 0) + info.totalEngineNanoseconds;
  });
  result.removeWhere((_, nanoseconds) => nanoseconds <= 0);
  return result;
}

/// Total engine time per engine over every client of [device], nanoseconds.
///
/// Engines run in parallel, so callers compare one engine against the elapsed
/// time instead of summing the values: the busiest engine is the GPU's busy
/// share, which is what a single "load" figure means.
Future<Map<String, int>> sampleEngineNanoseconds(GpuDevice device) async {
  final result = <String, int>{};
  await _forEachClient(device, (_, info) {
    info.engineNanoseconds.forEach((engine, nanoseconds) {
      result[engine] = (result[engine] ?? 0) + nanoseconds;
    });
  });
  return result;
}

/// Visits each DRM client of [device] once, with the pid that owns it.
Future<void> _forEachClient(
  GpuDevice device,
  void Function(int pid, DrmFdInfo info) visit,
) async {
  final seenClients = <int>{};
  final pids = await listProcessIds();
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
      visit(pid, info);
    }
  }
}
