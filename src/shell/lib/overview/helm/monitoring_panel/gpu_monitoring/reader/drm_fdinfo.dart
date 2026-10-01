/// One DRM client entry parsed from `/proc/<pid>/fdinfo/<fd>`.
///
/// The kernel exposes cumulative engine time (nanoseconds) and memory
/// accounting (KiB) per open DRM file, keyed by client id. A `dup` shares the
/// file description, so duplicate fds report identical counters.
class DrmFdInfo {
  /// Creates a parsed entry.
  const DrmFdInfo({
    required this.driver,
    this.pciId,
    this.pciDevice,
    this.clientId,
    this.engineNanoseconds = const {},
    this.memoryKib = const {},
  });

  /// `drm-driver`, e.g. `amdgpu`.
  final String driver;

  /// `drm-pci-id`, e.g. `0000:03:00.0`, matching the card's PCI address. Only
  /// some clients/kernels report it.
  final String? pciId;

  /// `drm-pdev`, e.g. `0000:03:00.0`. Reported by clients that omit
  /// `drm-pci-id`; same value, different key.
  final String? pciDevice;

  /// The card's PCI address as reported by this client, preferring the
  /// explicit `drm-pci-id`.
  String? get cardPciAddress => pciId ?? pciDevice;

  /// `drm-client-id`, identifying the open file description.
  final int? clientId;

  /// Per-engine cumulative time in nanoseconds, keyed by engine name
  /// (`gfx`, `compute`, `dma`, `enc`, `dec`, ...).
  final Map<String, int> engineNanoseconds;

  /// Per-region memory in KiB, keyed by region (`vram`, `gtt`, ...).
  final Map<String, int> memoryKib;

  /// Total engine time across engines, in nanoseconds.
  int get totalEngineNanoseconds =>
      engineNanoseconds.values.fold(0, (sum, value) => sum + value);
}

const _enginePrefix = 'drm-engine-';
const _memoryPrefix = 'drm-memory-';

/// Parses the contents of a `/proc/<pid>/fdinfo/<fd>` file.
///
/// Returns `null` when the file does not describe a DRM client. Numeric values
/// are followed by a unit (`ns`, `KiB`), which is stripped.
DrmFdInfo? parseDrmFdInfo(String contents) {
  String? driver;
  String? pciId;
  String? pciDevice;
  int? clientId;
  final engines = <String, int>{};
  final memory = <String, int>{};

  for (final line in contents.split('\n')) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    final value = line.substring(separator + 1).trim();
    if (key == 'drm-driver') {
      driver = value;
    } else if (key == 'drm-pci-id') {
      pciId = value;
    } else if (key == 'drm-pdev') {
      pciDevice = value;
    } else if (key == 'drm-client-id') {
      clientId = int.tryParse(value);
    } else if (key.startsWith(_enginePrefix)) {
      final nanoseconds = _parseLeadingInt(value);
      if (nanoseconds != null) {
        engines[key.substring(_enginePrefix.length)] = nanoseconds;
      }
    } else if (key.startsWith(_memoryPrefix)) {
      final kib = _parseLeadingInt(value);
      if (kib != null) memory[key.substring(_memoryPrefix.length)] = kib;
    }
  }

  if (driver == null) return null;
  return DrmFdInfo(
    driver: driver,
    pciId: pciId,
    pciDevice: pciDevice,
    clientId: clientId,
    engineNanoseconds: engines,
    memoryKib: memory,
  );
}

int? _parseLeadingInt(String value) {
  final first = value.split(RegExp(r'\s+')).firstWhere(
    (part) => part.isNotEmpty,
    orElse: () => '',
  );
  return int.tryParse(first);
}

/// Per-pid GPU busy share, in percent, between two cumulative engine samples.
///
/// [previous] and [current] map a pid to its total engine nanoseconds. A
/// process can exceed 100% when it uses several engines at once; the figure is
/// the sum over engines relative to wall-clock [elapsedNanoseconds].
Map<int, double> gpuBusyShares(
  Map<int, int> previous,
  Map<int, int> current,
  int elapsedNanoseconds,
) {
  if (elapsedNanoseconds <= 0) return const {};
  final shares = <int, double>{};
  current.forEach((pid, nanoseconds) {
    final before = previous[pid] ?? 0;
    final delta = nanoseconds - before;
    if (delta <= 0) return;
    shares[pid] = delta / elapsedNanoseconds * 100;
  });
  return shares;
}
