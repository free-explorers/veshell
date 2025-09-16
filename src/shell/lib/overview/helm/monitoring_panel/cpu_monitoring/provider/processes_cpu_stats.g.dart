// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processes_cpu_stats.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProcessesCpuStats)
const processesCpuStatsProvider = ProcessesCpuStatsProvider._();

final class ProcessesCpuStatsProvider
    extends $NotifierProvider<ProcessesCpuStats, IMap<int, double>> {
  const ProcessesCpuStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'processesCpuStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$processesCpuStatsHash();

  @$internal
  @override
  ProcessesCpuStats create() => ProcessesCpuStats();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IMap<int, double> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IMap<int, double>>(value),
    );
  }
}

String _$processesCpuStatsHash() => r'81a0cfa5c9ca6631788e13c7a3e9f239bd4c0483';

abstract class _$ProcessesCpuStats extends $Notifier<IMap<int, double>> {
  IMap<int, double> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<IMap<int, double>, IMap<int, double>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<IMap<int, double>, IMap<int, double>>,
              IMap<int, double>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
