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
    this.pciAddress,
    this.vendorId,
    this.hwmonPath,
    this.isBootVga = false,
  });

  /// `/sys/class/drm/cardN`.
  final String cardPath;

  /// Driver name decoded from `device/driver`, e.g. `amdgpu`.
  final String driver;

  /// PCI address from `device`, e.g. `0000:03:00.0`. Matches the
  /// `drm-pci-id` of a client's `fdinfo`, so per-process data can be filtered
  /// to this card.
  final String? pciAddress;

  /// PCI vendor id from `device/vendor`, e.g. `0x1002`.
  final int? vendorId;

  /// `/sys/class/drm/cardN/device/hwmon/hwmonX`, when the card exposes one.
  final String? hwmonPath;

  /// Whether the firmware marked this card as the boot VGA device.
  final bool isBootVga;
}

final _cardPattern = RegExp(r'^card(\d+)$');

/// Chooses which detected GPU to report.
///
/// Mirrors the compositor's own choice in `drm_backend.rs`: an explicit
/// `DRM_DEVICE` override wins (either a `cardN` or a `renderDN` path),
/// otherwise the boot VGA device, otherwise the lowest-numbered card. Cards
/// must be passed lowest-numbered first.
///
/// [renderNodeToCard] maps a `renderDN` name to the card that owns it, for the
/// `DRM_DEVICE=/dev/dri/renderDXXX` form. It is a parameter so the selection can
/// be unit tested without sysfs.
GpuDevice? selectGpuDevice(
  List<GpuDevice> candidates, {
  String? devicePathOverride,
  Map<String, GpuDevice> renderNodeToCard = const {},
}) {
  if (candidates.isEmpty) return null;

  if (devicePathOverride != null && devicePathOverride.isNotEmpty) {
    final name = p.basename(devicePathOverride.replaceAll(RegExp(r'/+$'), ''));
    for (final candidate in candidates) {
      if (p.basename(candidate.cardPath) == name) return candidate;
    }
    final viaRenderNode = renderNodeToCard[name];
    if (viaRenderNode != null) return viaRenderNode;
  }

  for (final candidate in candidates) {
    if (candidate.isBootVga) return candidate;
  }
  return candidates.first;
}

/// Detects the GPU to report, or `null` when none exposes amdgpu telemetry.
GpuDevice? detectGpuDevice() {
  final candidates = _detectCandidates();
  if (candidates.isEmpty) return null;
  return selectGpuDevice(
    candidates,
    devicePathOverride: Platform.environment['DRM_DEVICE'],
    renderNodeToCard: _renderNodeToCard(candidates),
  );
}

List<GpuDevice> _detectCandidates() {
  final drm = Directory('/sys/class/drm');
  if (!drm.existsSync()) return const [];

  final cards = <({int number, String path})>[];
  try {
    // `/sys/class/drm/cardN` entries are symlinks to the real device
    // directories, so the link must be followed for the type check to see a
    // Directory.
    for (final entity in drm.listSync()) {
      if (entity is! Directory) continue;
      final match = _cardPattern.firstMatch(p.basename(entity.path));
      if (match == null) continue;
      cards.add((number: int.parse(match.group(1)!), path: entity.path));
    }
  } on FileSystemException {
    return const [];
  }
  cards.sort((a, b) => a.number.compareTo(b.number));

  final candidates = <GpuDevice>[];
  for (final card in cards) {
    final devicePath = '${card.path}/device';
    if (!File('$devicePath/gpu_busy_percent').existsSync()) continue;
    candidates.add(
      GpuDevice(
        cardPath: card.path,
        driver: _driverName(devicePath),
        pciAddress: _pciAddress(devicePath),
        vendorId: _readHexSync('$devicePath/vendor'),
        hwmonPath: _findHwmon(devicePath),
        isBootVga: _readTextSync('$devicePath/boot_vga')?.trim() == '1',
      ),
    );
  }
  return candidates;
}

Map<String, GpuDevice> _renderNodeToCard(List<GpuDevice> candidates) {
  final map = <String, GpuDevice>{};
  for (final candidate in candidates) {
    try {
      final drmDir = p.dirname(
        Directory(candidate.cardPath).resolveSymbolicLinksSync(),
      );
      for (final entity in Directory(drmDir).listSync()) {
        final name = p.basename(entity.path);
        if (name.startsWith('renderD')) map[name] = candidate;
      }
    } on FileSystemException {
      // Keep the other candidates; only the override lookup suffers.
    }
  }
  return map;
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

String? _readTextSync(String path) {
  try {
    return File(path).readAsStringSync();
  } on FileSystemException {
    return null;
  }
}

String _driverName(String devicePath) {
  try {
    return p.basename(Link('$devicePath/driver').targetSync());
  } on FileSystemException {
    return 'unknown';
  }
}

String? _pciAddress(String devicePath) {
  try {
    return p.basename(Directory(devicePath).resolveSymbolicLinksSync());
  } on FileSystemException {
    return null;
  }
}

int? _readHexSync(String path) {
  final text = _readTextSync(path)?.trim();
  if (text == null) return null;
  final digits = text.startsWith('0x') ? text.substring(2) : text;
  return int.tryParse(digits, radix: 16);
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
