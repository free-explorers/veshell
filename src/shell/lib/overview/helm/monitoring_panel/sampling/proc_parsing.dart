import 'dart:math' as math;

/// Pure parsers for the `/proc` files the monitoring panel reads.
///
/// Everything here is string-in / data-out so the parsing and the percentage
/// math can be unit tested without a live `/proc`.

/// A single `cpu...` line of `/proc/stat`.
///
/// The kernel appends fields over time (`guest` and `guest_nice` were added
/// later), so [ticks] keeps only what the file carried; [tick] reads a missing
/// field as zero instead of throwing.
class CpuLine {
  /// Creates a line from its `label` and raw `ticks`, starting at `user`.
  const CpuLine({required this.label, required this.ticks});

  /// `cpu` for the aggregate line, `cpu0`, `cpu1`, ... for one core.
  final String label;

  /// Raw counters in clock ticks, starting at `user`.
  final List<int> ticks;

  /// The counter at [index], or `0` when the kernel did not report it.
  int tick(int index) => index < ticks.length ? ticks[index] : 0;

  /// Ticks spent in user mode.
  int get user => tick(0);

  /// Ticks spent in user mode with low priority.
  int get nice => tick(1);

  /// Ticks spent in system mode.
  int get system => tick(2);

  /// Ticks spent idle.
  int get idle => tick(3);

  /// Ticks spent waiting for I/O.
  int get iowait => tick(4);

  /// Ticks spent servicing interrupts.
  int get irq => tick(5);

  /// Ticks spent servicing softirqs.
  int get softirq => tick(6);

  /// Ticks stolen by a hypervisor.
  int get steal => tick(7);

  /// Total non-guest ticks.
  ///
  /// `guest`/`guest_nice` are already counted in `user`/`nice`, so they must
  /// not be added again.
  int get total => user + nice + system + idle + iowait + irq + softirq + steal;

  /// Ticks the CPU was not idle. [idle] includes [iowait].
  int get idleTicks => idle + iowait;
}

final _cpuLinePattern = RegExp(r'^cpu\d*$');

/// Parses `/proc/stat`, aggregate `cpu` line first, then one line per core.
///
/// Lines that are not `cpu`/`cpuN` (or that carry a non-numeric counter) are
/// skipped rather than throwing, so a partial read cannot break a sample.
List<CpuLine> parseProcStat(String contents) {
  final lines = <CpuLine>[];
  for (final raw in contents.split('\n')) {
    final fields = raw
        .split(RegExp(r'\s+'))
        .where((field) => field.isNotEmpty)
        .toList();
    if (fields.isEmpty || !_cpuLinePattern.hasMatch(fields.first)) {
      continue;
    }
    final ticks = <int>[];
    var malformed = false;
    for (final field in fields.skip(1)) {
      final value = int.tryParse(field);
      if (value == null) {
        malformed = true;
        break;
      }
      ticks.add(value);
    }
    if (malformed) continue;
    lines.add(CpuLine(label: fields.first, ticks: ticks));
  }
  return lines;
}

/// Percentage of time spent non-idle between two samples of the same line.
///
/// Returns `0` when the counters did not move (or went backwards, e.g. after a
/// counter reset) so the caller never divides by zero. The result is clamped
/// to `0..100`.
double cpuUsagePercent(CpuLine previous, CpuLine now) {
  final total = now.total - previous.total;
  if (total <= 0) return 0;
  final idle = now.idleTicks - previous.idleTicks;
  return ((total - idle) / total * 100).clamp(0, 100);
}

/// Parses `/proc/meminfo` into field name to value in kB.
///
/// Values without a numeric prefix are dropped.
Map<String, int> parseMemInfo(String contents) {
  final values = <String, int>{};
  for (final line in contents.split('\n')) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    final value = int.tryParse(
      line.substring(separator + 1).trim().split(RegExp(r'\s+')).first,
    );
    if (value != null) values[line.substring(0, separator)] = value;
  }
  return values;
}

/// Used memory in kB, preferring the kernel's `MemAvailable` estimate.
///
/// `MemAvailable` already accounts for reclaimable slab and page cache. The
/// fallback (for kernels before 3.14) mirrors `htop`: subtract `SReclaimable`
/// and add back `Shmem`, which `Cached` also includes.
int memoryUsedKb(Map<String, int> info) {
  final total = info['MemTotal'] ?? 0;
  final available = info['MemAvailable'];
  if (available != null) {
    return math.max(0, total - available);
  }
  return math.max(
    0,
    total -
        (info['MemFree'] ?? 0) -
        (info['Buffers'] ?? 0) -
        (info['Cached'] ?? 0) -
        (info['SReclaimable'] ?? 0) +
        (info['Shmem'] ?? 0),
  );
}

/// Used memory as a whole percentage, clamped to `0..100`.
int memoryUsedPercent(Map<String, int> info) {
  final total = info['MemTotal'] ?? 0;
  if (total <= 0) return 0;
  return (memoryUsedKb(info) / total * 100).clamp(0, 100).round();
}

/// `utime` and `stime`, in clock ticks, from `/proc/<pid>/stat`.
///
/// The command name is parenthesised and may itself contain spaces or
/// parentheses, so the numeric fields are located after the *last* `)` rather
/// than by splitting the whole line. `state` is the first token after it, which
/// puts `utime`/`stime` (fields 14 and 15) at indices 11 and 12.
({int utime, int stime})? parseProcPidStat(String contents) {
  final open = contents.indexOf('(');
  final close = contents.lastIndexOf(')');
  if (open < 0 || close <= open) return null;
  final fields = contents
      .substring(close + 1)
      .split(RegExp(r'\s+'))
      .where((field) => field.isNotEmpty)
      .toList();
  if (fields.length <= 12) return null;
  final utime = int.tryParse(fields[11]);
  final stime = int.tryParse(fields[12]);
  if (utime == null || stime == null) return null;
  return (utime: utime, stime: stime);
}

/// Resident set size in pages from `/proc/<pid>/statm` (the second field).
int? parseProcPidStatmResidentPages(String contents) {
  final fields = contents.trim().split(RegExp(r'\s+'));
  if (fields.length < 2) return null;
  return int.tryParse(fields[1]);
}
