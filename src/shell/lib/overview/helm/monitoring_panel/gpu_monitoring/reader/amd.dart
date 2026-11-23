import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_parsing.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

/// Reads amdgpu device telemetry, or `null` when the card became unusable.
///
/// Synchronous: it runs on the monitoring sampler's isolate, where blocking
/// on a handful of sysfs attributes costs no frame.
GpuStats? readAmdGpuStats(GpuDevice device) {
  final devicePath = '${device.cardPath}/device';
  final hwmon = device.hwmonPath;
  final raw = GpuRawValues(
    busyPercent: _readInt('$devicePath/gpu_busy_percent'),
    vramUsedBytes: _readInt('$devicePath/mem_info_vram_used'),
    vramTotalBytes: _readInt('$devicePath/mem_info_vram_total'),
    gttUsedBytes: _readInt('$devicePath/mem_info_gtt_used'),
    gttTotalBytes: _readInt('$devicePath/mem_info_gtt_total'),
    temperatureMilliCelsius: hwmon == null
        ? null
        : _readInt('$hwmon/temp1_input'),
    powerMicrowatts: hwmon == null ? null : _readInt('$hwmon/power1_input'),
    coreClockHertz: hwmon == null ? null : _readInt('$hwmon/freq1_input'),
    memoryClockHertz: hwmon == null ? null : _readInt('$hwmon/freq2_input'),
  );
  return buildGpuStats(raw);
}

int? _readInt(String path) {
  final text = readTextFileSync(path);
  return text == null ? null : int.tryParse(text.trim());
}
