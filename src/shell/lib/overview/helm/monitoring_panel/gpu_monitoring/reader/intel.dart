import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

/// i915 exposes the RPS frequencies at the card root (older) or under `gt`.
const _i915Current = [
  'gt_act_freq_mhz',
  'gt_cur_freq_mhz',
  'gt/gt0/rps_act_freq_mhz',
  'gt/gt0/rps_cur_freq_mhz',
];
const _i915Max = [
  'gt_max_freq_mhz',
  'gt_RP0_freq_mhz',
  'gt/gt0/rps_max_freq_mhz',
  'gt/gt0/rps_RP0_freq_mhz',
];
const _i915Min = [
  'gt_min_freq_mhz',
  'gt_RPn_freq_mhz',
  'gt/gt0/rps_min_freq_mhz',
  'gt/gt0/rps_RPn_freq_mhz',
];

/// xe exposes per-tile/GT frequencies under the PCI device.
const _xeCurrent = ['device/tile0/gt0/freq0/act_freq', 'device/tile0/gt0/freq0/cur_freq'];
const _xeMax = ['device/tile0/gt0/freq0/rp0_freq'];
const _xeMin = ['device/tile0/gt0/freq0/rpn_freq'];

/// Reads Intel (i915/xe) telemetry.
///
/// Intel exposes no root-free busy counter: `i915_engine_info` is debugfs
/// (root) and true engine busyness needs the i915 PMU through `perf_event_open`
/// (privileged). [GpuStats.load] is therefore the RPS frequency relative to its
/// min/max — a proxy for activity, not engine utilisation. Returns `null` when
/// nothing at all is readable, so the card is then omitted.
Future<GpuStats?> readIntelGpuStats(GpuDevice device) async {
  final card = device.cardPath;
  final current = await _firstInt(card, [..._i915Current, ..._xeCurrent]);
  final maximum = await _firstInt(card, [..._i915Max, ..._xeMax]);
  final minimum = await _firstInt(card, [..._i915Min, ..._xeMin]);
  final hwmon = device.hwmonPath;
  final temperatureMilli = hwmon == null
      ? null
      : await _readInt('$hwmon/temp1_input');

  final load = intelLoadFromFrequency(
    current: current,
    min: minimum,
    max: maximum,
  );
  if (current == null && temperatureMilli == null) return null;

  return GpuStats(
    load: load ?? 0,
    temperatureCelsius:
        temperatureMilli == null ? null : temperatureMilli / 1000,
    coreClockMhz: current,
  );
}

/// Frequency relative to the RPS min/max, as a `0..100` activity proxy.
///
/// `null` when any bound is missing or the range is degenerate.
int? intelLoadFromFrequency({int? current, int? min, int? max}) {
  if (current == null || min == null || max == null || max <= min) return null;
  return ((current - min) / (max - min) * 100).clamp(0, 100).round();
}

Future<int?> _firstInt(String base, List<String> relatives) async {
  for (final relative in relatives) {
    final value = await _readInt('$base/$relative');
    if (value != null) return value;
  }
  return null;
}

Future<int?> _readInt(String path) async {
  final text = await readTextFile(path);
  return text == null ? null : int.tryParse(text.trim());
}
