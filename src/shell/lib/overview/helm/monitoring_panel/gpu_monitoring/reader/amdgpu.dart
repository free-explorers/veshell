import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/amdgpu_parsing.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

/// A DRM card exposing telemetry the shell knows how to read.
class GpuDevice {
  /// Creates a device handle.
  const GpuDevice({
    required this.cardPath,
    required this.driver,
    this.vendorId,
    this.hwmonPath,
  });

  /// `/sys/class/drm/cardN`.
  final String cardPath;

  /// Driver name decoded from `device/driver`, e.g. `amdgpu`.
  final String driver;

  /// PCI vendor id from `device/vendor`, e.g. `0x1002`.
  final int? vendorId;

  /// `/sys/class/drm/cardN/device/hwmon/hwmonX`, when the card exposes one.
  final String? hwmonPath;
}

final _cardPattern = RegExp(r'^card(\d+)$');

/// Finds the first DRM card with the amdgpu telemetry interface.
///
/// Cards are sorted by their number so the choice is stable across calls. Only
/// one GPU is reported: on multi-GPU systems this is the lowest-numbered card
/// exposing `gpu_busy_percent`.
GpuDevice? detectGpuDevice() {
  final drm = Directory('/sys/class/drm');
  if (!drm.existsSync()) return null;

  final cards = <({int number, String path})>[];
  try {
    for (final entity in drm.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      final match = _cardPattern.firstMatch(p.basename(entity.path));
      if (match == null) continue;
      cards.add((number: int.parse(match.group(1)!), path: entity.path));
    }
  } on FileSystemException {
    return null;
  }
  cards.sort((a, b) => a.number.compareTo(b.number));

  for (final card in cards) {
    final devicePath = '${card.path}/device';
    if (!File('$devicePath/gpu_busy_percent').existsSync()) continue;
    return GpuDevice(
      cardPath: card.path,
      driver: _driverName(devicePath),
      vendorId: _readHexSync('$devicePath/vendor'),
      hwmonPath: _findHwmon(devicePath),
    );
  }
  return null;
}

/// Reads the current telemetry of [device], or `null` when it became unusable.
Future<GpuStats?> readGpuStats(GpuDevice device) async {
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

String _driverName(String devicePath) {
  try {
    return p.basename(Link('$devicePath/driver').targetSync());
  } on FileSystemException {
    return 'unknown';
  }
}

int? _readHexSync(String path) {
  try {
    final text = File(path).readAsStringSync().trim();
    final digits = text.startsWith('0x') ? text.substring(2) : text;
    return int.tryParse(digits, radix: 16);
  } on FileSystemException {
    return null;
  }
}

String? _findHwmon(String devicePath) {
  final hwmon = Directory('$devicePath/hwmon');
  if (!hwmon.existsSync()) return null;
  try {
    for (final entity in hwmon.listSync()) {
      if (entity is Directory && p.basename(entity.path).startsWith('hwmon')) {
        return entity.path;
      }
    }
  } on FileSystemException {
    return null;
  }
  return null;
}
