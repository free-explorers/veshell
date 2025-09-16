// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_chart.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MemoryChart)
const memoryChartProvider = MemoryChartProvider._();

final class MemoryChartProvider
    extends $NotifierProvider<MemoryChart, List<FlSpot>> {
  const MemoryChartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryChartProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryChartHash();

  @$internal
  @override
  MemoryChart create() => MemoryChart();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<FlSpot> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<FlSpot>>(value),
    );
  }
}

String _$memoryChartHash() => r'ce191e48255e49252034d8113f4e072057ad4ece';

abstract class _$MemoryChart extends $Notifier<List<FlSpot>> {
  List<FlSpot> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<FlSpot>, List<FlSpot>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<FlSpot>, List<FlSpot>>,
              List<FlSpot>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
