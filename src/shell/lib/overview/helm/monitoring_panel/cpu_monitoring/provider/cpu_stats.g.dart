// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cpu_stats.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CpuStatsState)
const cpuStatsStateProvider = CpuStatsStateProvider._();

final class CpuStatsStateProvider
    extends $NotifierProvider<CpuStatsState, CpuStats> {
  const CpuStatsStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cpuStatsStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cpuStatsStateHash();

  @$internal
  @override
  CpuStatsState create() => CpuStatsState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CpuStats value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CpuStats>(value),
    );
  }
}

String _$cpuStatsStateHash() => r'e846e9c890b544692755676c694ee97d492bbbef';

abstract class _$CpuStatsState extends $Notifier<CpuStats> {
  CpuStats build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CpuStats, CpuStats>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CpuStats, CpuStats>,
              CpuStats,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
