import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_parsing.dart';

part 'processes_memory_stats.g.dart';

/// Per-process resident memory as a percentage of total memory, sampled only
/// while the memory card is expanded.
///
/// The figure is RSS, so pages shared between processes count for each of them
/// and the percentages can add up to more than 100%.
@riverpod
class ProcessesMemoryStats extends _$ProcessesMemoryStats {
  @override
  IMap<int, double> build() {
    final cancel = startPolling(monitoringSampleInterval, _sample);
    ref.onDispose(cancel);
    return <int, double>{}.lock;
  }

  Future<void> _sample() async {
    final memInfo = await readTextFile('/proc/meminfo');
    if (!ref.mounted || memInfo == null) return;
    final totalKb = parseMemInfo(memInfo)['MemTotal'] ?? 0;
    if (totalKb <= 0) return;
    final totalBytes = totalKb * 1024;

    final pids = await listProcessIds();
    if (!ref.mounted) return;
    final percentages = <int, double>{};
    for (final pid in pids) {
      if (isKernelThread(pid)) continue;
      final statm = await readTextFile('/proc/$pid/statm');
      if (statm == null) continue;
      final pages = parseProcPidStatmResidentPages(statm);
      if (pages == null) continue;
      percentages[pid] = pages * systemPageSize / totalBytes * 100;
    }
    state = percentages.lock;
  }
}
