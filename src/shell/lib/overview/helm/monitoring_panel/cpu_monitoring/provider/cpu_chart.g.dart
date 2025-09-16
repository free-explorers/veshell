// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cpu_chart.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CpuChart)
const cpuChartProvider = CpuChartProvider._();

final class CpuChartProvider extends $NotifierProvider<CpuChart, List<FlSpot>> {
  const CpuChartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cpuChartProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cpuChartHash();

  @$internal
  @override
  CpuChart create() => CpuChart();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<FlSpot> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<FlSpot>>(value),
    );
  }
}

String _$cpuChartHash() => r'883ba166964264e3ac70de13b8cfca60efccdd8a';

abstract class _$CpuChart extends $Notifier<List<FlSpot>> {
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
