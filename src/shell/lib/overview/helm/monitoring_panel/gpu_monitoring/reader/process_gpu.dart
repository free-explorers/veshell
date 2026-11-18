import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/drm_fdinfo.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

/// Per-pid total GPU engine time, in nanoseconds, for clients of [device].
///
/// A DRM client shared between processes (an fd inherited across fork or passed
/// over SCM_RIGHTS) counts for each holder: this is attribution, not a total.
/// Processes with no client on [device] are omitted.
Future<Map<int, int>> sampleProcessEngineNanoseconds(GpuDevice device) async {
  final sample = await sampleDevice(device);
  return sample.processNanoseconds;
}

/// Engine time per DRM client of [device], in nanoseconds, keyed by
/// `drm-client-id` and then by engine.
///
/// A client id is unique per device, so one client is counted once even when
/// several processes hold it. Keeping the values per client lets callers
/// difference them between samples: a client that exits then loses only its own
/// counters instead of subtracting its lifetime from the total.
Future<Map<int, Map<String, int>>> sampleClientEngineNanoseconds(
  GpuDevice device,
) async {
  final sample = await sampleDevice(device);
  return sample.clientEngines;
}

/// One walk of a [GpuDevice]'s DRM clients, shared by the card and the list.
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

DeviceEngineSample? _cached;
String? _cachedCard;
DateTime? _cachedAt;
Future<DeviceEngineSample>? _pending;

/// How long one scan serves both callers.
///
/// The card and the per-process list sample on the same interval; sharing the
/// walk keeps them from scanning `/proc` twice for one reading.
const _cacheFor = Duration(milliseconds: 400);

/// Samples [device]'s clients off the UI isolate and caches the walk briefly.
Future<DeviceEngineSample> sampleDevice(GpuDevice device) {
  final now = DateTime.now();
  final cached = _cached;
  if (cached != null &&
      _cachedCard == device.cardPath &&
      _cachedAt != null &&
      now.difference(_cachedAt!) < _cacheFor) {
    return Future.value(cached);
  }
  // Share the walk between callers that miss the cache together.
  return _pending ??= Isolate.run(() => walkDeviceClients(device))
      .then((sample) {
        _cached = sample;
        _cachedCard = device.cardPath;
        _cachedAt = DateTime.now();
        return sample;
      })
      .whenComplete(() => _pending = null);
}

/// Walks `/proc` for [device]'s clients. Top-level so it can run off-isolate.
Future<DeviceEngineSample> walkDeviceClients(GpuDevice device) async {
  final processNanoseconds = <int, int>{};
  final clientEngines = <int, Map<String, int>>{};
  final seenClients = <int>{};
  final seenPerPid = <int, Set<int>>{};
  var hasEngineCounters = false;

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
