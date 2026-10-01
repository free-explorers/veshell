import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_parsing.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

/// Reads amdgpu device telemetry, or `null` when the card became unusable.
Future<GpuStats?> readAmdGpuStats(GpuDevice device) async {
  final devicePath = '${device.cardPath}/device';
  final hwmon = device.hwmonPath;
  final raw = GpuRawValues(
    busyPercent: await _readInt('$devicePath/gpu_busy_percent'),
    vramUsedBytes: await _readInt('$devicePath/mem_info_vram_used'),
    vramTotalBytes: await _readInt('$devicePath/mem_info_vram_total'),
    gttUsedBytes: await _readInt('$devicePath/mem_info_gtt_used'),
    gttTotalBytes: await _readInt('$devicePath/mem_info_gtt_total'),
    temperatureMilliCelsius: hwmon == null
        ? null
        : await _readInt('$hwmon/temp1_input'),
    powerMicrowatts: hwmon == null ? null : await _readInt('$hwmon/power1_input'),
    coreClockHertz: hwmon == null ? null : await _readInt('$hwmon/freq1_input'),
    memoryClockHertz: hwmon == null
        ? null
        : await _readInt('$hwmon/freq2_input'),
  );
  return buildGpuStats(raw);
}

Future<int?> _readInt(String path) async {
  final text = await readTextFile(path);
  return text == null ? null : int.tryParse(text.trim());
}
