// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processes_memory_stats.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProcessesMemoryStats)
const processesMemoryStatsProvider = ProcessesMemoryStatsProvider._();

final class ProcessesMemoryStatsProvider
    extends $NotifierProvider<ProcessesMemoryStats, IMap<int, double>> {
  const ProcessesMemoryStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'processesMemoryStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$processesMemoryStatsHash();

  @$internal
  @override
  ProcessesMemoryStats create() => ProcessesMemoryStats();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IMap<int, double> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IMap<int, double>>(value),
    );
  }
}

String _$processesMemoryStatsHash() =>
    r'5afbcb99289a998a18ec4e842c667068504040ac';

abstract class _$ProcessesMemoryStats extends $Notifier<IMap<int, double>> {
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
