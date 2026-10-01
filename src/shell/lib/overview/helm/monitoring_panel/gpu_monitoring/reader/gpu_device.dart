import 'dart:io';

import 'package:path/path.dart' as p;

/// Vendor of a detected GPU, which selects the reader.
enum GpuVendor {
  /// AMD, read from the amdgpu sysfs.
  amd,

  /// Intel i915 / xe, read from sysfs.
  intel,

  /// NVIDIA, read through NVML.
  nvidia,

  /// Recognized as a DRM card but with no reader.
  unknown,
}

/// A GPU the shell can report on.
class GpuDevice {
  /// Creates a device handle.
  const GpuDevice({
    required this.cardPath,
    required this.driver,
    required this.vendor,
    this.pciAddress,
    this.vendorId,
    this.hwmonPath,
    this.isBootVga = false,
    this.nvidiaIndex,
  });

  /// `/sys/class/drm/cardN`, or empty for a device with no DRM node.
  final String cardPath;

  /// Driver name decoded from `device/driver`, e.g. `amdgpu`.
  final String driver;

  /// Which reader to use.
  final GpuVendor vendor;

  /// PCI address from `device`, e.g. `0000:03:00.0`, also used to filter
  /// `fdinfo` clients to this card.
  final String? pciAddress;

  /// PCI vendor id from `device/vendor`, e.g. `0x1002`.
  final int? vendorId;

  /// `/sys/class/drm/cardN/device/hwmon/hwmonX`, when the card exposes one.
  final String? hwmonPath;

  /// Whether the firmware marked this card as the boot VGA device.
  final bool isBootVga;

  /// NVML device index, for NVIDIA. `null` selects the first device.
  final int? nvidiaIndex;
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
/// `DRM_DEVICE=/dev/dri/renderDXXX` form. It is a parameter so the selection
/// can be unit tested without sysfs.
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

/// Detects the GPU to report, or `null` when no supported one is present.
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
    final driver = _driverName(devicePath);
    final vendorId = _readHexSync('$devicePath/vendor');
    final vendor = _vendorFor(vendorId, driver);
    if (vendor == GpuVendor.unknown) continue;
    // AMD is only usable when the kernel exposes the busy counter; Intel and
    // NVIDIA have no such file.
    if (vendor == GpuVendor.amd &&
        !File('$devicePath/gpu_busy_percent').existsSync()) {
      continue;
    }
    candidates.add(
      GpuDevice(
        cardPath: card.path,
        driver: driver,
        vendor: vendor,
        pciAddress: _pciAddress(devicePath),
        vendorId: vendorId,
        hwmonPath: _findHwmon(devicePath),
        isBootVga: _readTextSync('$devicePath/boot_vga')?.trim() == '1',
      ),
    );
  }
  return candidates;
}

GpuVendor _vendorFor(int? vendorId, String driver) {
  if (vendorId == 0x1002 || driver == 'amdgpu') return GpuVendor.amd;
  if (vendorId == 0x8086 || driver == 'i915' || driver == 'xe') {
    return GpuVendor.intel;
  }
  if (vendorId == 0x10de || driver.startsWith('nvidia')) {
    return GpuVendor.nvidia;
  }
  return GpuVendor.unknown;
}

Map<String, GpuDevice> _renderNodeToCard(List<GpuDevice> candidates) {
  final map = <String, GpuDevice>{};
  for (final candidate in candidates) {
    if (candidate.cardPath.isEmpty) continue;
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

String? _readTextSync(String path) {
  try {
    return File(path).readAsStringSync();
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
