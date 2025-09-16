// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_stats.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MemoryStatsState)
const memoryStatsStateProvider = MemoryStatsStateProvider._();

final class MemoryStatsStateProvider
    extends $NotifierProvider<MemoryStatsState, MemoryStats> {
  const MemoryStatsStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryStatsStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryStatsStateHash();

  @$internal
  @override
  MemoryStatsState create() => MemoryStatsState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryStats value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryStats>(value),
    );
  }
}

String _$memoryStatsStateHash() => r'954015a7096e0bb831bfefb3d95aca797199da69';

abstract class _$MemoryStatsState extends $Notifier<MemoryStats> {
  MemoryStats build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<MemoryStats, MemoryStats>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MemoryStats, MemoryStats>,
              MemoryStats,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
