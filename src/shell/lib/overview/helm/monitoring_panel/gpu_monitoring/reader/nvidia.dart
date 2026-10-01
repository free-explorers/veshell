import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';

const int _nvmlSuccess = 0;
const int _nvmlTemperatureGpu = 0;
const int _nvmlClockGraphics = 0;
const int _nvmlClockMemory = 2;
const int _bytesPerMegabyte = 1024 * 1024;

final class _NvmlUtilization extends Struct {
  @Uint32()
  external int gpu;

  @Uint32()
  external int memory;
}

final class _NvmlMemory extends Struct {
  @Uint64()
  external int total;

  @Uint64()
  external int free;

  @Uint64()
  external int used;
}

typedef _InitNative = Int32 Function();
typedef _InitDart = int Function();
typedef _HandleNative = Int32 Function(Uint32, Pointer<Pointer<Void>>);
typedef _HandleDart = int Function(int, Pointer<Pointer<Void>>);
typedef _UtilizationNative = Int32 Function(
  Pointer<Void>,
  Pointer<_NvmlUtilization>,
);
typedef _UtilizationDart = int Function(
  Pointer<Void>,
  Pointer<_NvmlUtilization>,
);
typedef _MemoryNative = Int32 Function(Pointer<Void>, Pointer<_NvmlMemory>);
typedef _MemoryDart = int Function(Pointer<Void>, Pointer<_NvmlMemory>);
typedef _TemperatureNative = Int32 Function(
  Pointer<Void>,
  Uint32,
  Pointer<Uint32>,
);
typedef _TemperatureDart = int Function(Pointer<Void>, int, Pointer<Uint32>);
typedef _ValueNative = Int32 Function(Pointer<Void>, Pointer<Uint32>);
typedef _ValueDart = int Function(Pointer<Void>, Pointer<Uint32>);
typedef _ClockNative = Int32 Function(Pointer<Void>, Uint32, Pointer<Uint32>);
typedef _ClockDart = int Function(Pointer<Void>, int, Pointer<Uint32>);

/// Lazily-bound subset of NVML, sufficient for device telemetry.
///
/// NVML is the only root-free way to read NVIDIA utilisation (`nvidia-smi`
/// would spawn a process per sample). The binding is optional: if
/// `libnvidia-ml` is missing or a symbol does not resolve, [instance] returns
/// `null` and the NVIDIA reader degrades to no card.
class _Nvml {
  _Nvml._(DynamicLibrary library)
    : _init = library.lookupFunction<_InitNative, _InitDart>('nvmlInit_v2'),
      _handle = library.lookupFunction<_HandleNative, _HandleDart>(
        'nvmlDeviceGetHandleByIndex_v2',
      ),
      _utilization = library
          .lookupFunction<_UtilizationNative, _UtilizationDart>(
        'nvmlDeviceGetUtilizationRates',
      ),
      _memory = library.lookupFunction<_MemoryNative, _MemoryDart>(
        'nvmlDeviceGetMemoryInfo',
      ),
      _temperature = library
          .lookupFunction<_TemperatureNative, _TemperatureDart>(
        'nvmlDeviceGetTemperature',
      ),
      _powerUsage = library.lookupFunction<_ValueNative, _ValueDart>(
        'nvmlDeviceGetPowerUsage',
      ),
      _clockInfo = library.lookupFunction<_ClockNative, _ClockDart>(
        'nvmlDeviceGetClockInfo',
      );

  final _InitDart _init;
  final _HandleDart _handle;
  final _UtilizationDart _utilization;
  final _MemoryDart _memory;
  final _TemperatureDart _temperature;
  final _ValueDart _powerUsage;
  final _ClockDart _clockInfo;

  static _Nvml? _instance;
  static bool _attempted = false;

  /// The process-wide binding, or `null` when NVML is unavailable.
  static _Nvml? instance() {
    if (_attempted) return _instance;
    _attempted = true;
    for (final name in const ['libnvidia-ml.so.1', 'libnvidia-ml.so']) {
      try {
        final nvml = _Nvml._(DynamicLibrary.open(name));
        if (nvml._init() == _nvmlSuccess) {
          _instance = nvml;
          break;
        }
      } on Object {
        // Try the next soname; a missing symbol also lands here.
      }
    }
    return _instance;
  }

  int handleByIndex(int index, Pointer<Pointer<Void>> out) =>
      _handle(index, out);

  int utilization(Pointer<Void> handle, Pointer<_NvmlUtilization> out) =>
      _utilization(handle, out);

  int memory(Pointer<Void> handle, Pointer<_NvmlMemory> out) =>
      _memory(handle, out);

  int temperature(Pointer<Void> handle, int sensor, Pointer<Uint32> out) =>
      _temperature(handle, sensor, out);

  int powerUsage(Pointer<Void> handle, Pointer<Uint32> out) =>
      _powerUsage(handle, out);

  int clockInfo(Pointer<Void> handle, int type, Pointer<Uint32> out) =>
      _clockInfo(handle, type, out);
}

/// Reads NVIDIA telemetry through NVML, or `null` when unavailable.
Future<GpuStats?> readNvidiaGpuStats(GpuDevice device) async {
  final nvml = _Nvml.instance();
  if (nvml == null) return null;
  return _read(device, nvml);
}

GpuStats? _read(GpuDevice device, _Nvml nvml) {
  return using((arena) {
    final handlePointer = arena<Pointer<Void>>();
    if (nvml.handleByIndex(device.nvidiaIndex ?? 0, handlePointer) !=
        _nvmlSuccess) {
      return null;
    }
    final handle = handlePointer.value;

    int? load;
    final utilization = arena<_NvmlUtilization>();
    if (nvml.utilization(handle, utilization) == _nvmlSuccess) {
      load = utilization.ref.gpu;
    }

    int? vramUsedMb;
    int? vramTotalMb;
    final memory = arena<_NvmlMemory>();
    if (nvml.memory(handle, memory) == _nvmlSuccess) {
      vramTotalMb = memory.ref.total ~/ _bytesPerMegabyte;
      vramUsedMb = memory.ref.used ~/ _bytesPerMegabyte;
    }

    final value = arena<Uint32>();
    double? temperature;
    if (nvml.temperature(handle, _nvmlTemperatureGpu, value) == _nvmlSuccess) {
      temperature = value.value.toDouble();
    }
    double? power;
    if (nvml.powerUsage(handle, value) == _nvmlSuccess) {
      power = value.value / 1000;
    }
    int? coreClock;
    if (nvml.clockInfo(handle, _nvmlClockGraphics, value) == _nvmlSuccess) {
      coreClock = value.value;
    }
    int? memoryClock;
    if (nvml.clockInfo(handle, _nvmlClockMemory, value) == _nvmlSuccess) {
      memoryClock = value.value;
    }

    if (load == null && vramTotalMb == null) return null;
    return GpuStats(
      load: (load ?? 0).clamp(0, 100),
      vramUsedMb: vramUsedMb ?? 0,
      vramTotalMb: vramTotalMb ?? 0,
      temperatureCelsius: temperature,
      powerWatts: power,
      coreClockMhz: coreClock,
      memoryClockMhz: memoryClock,
    );
  });
}
