// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nm_statistics.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NmStatistics)
const nmStatisticsProvider = NmStatisticsFamily._();

final class NmStatisticsProvider
    extends $NotifierProvider<NmStatistics, NetworkManagerDeviceStatistics> {
  const NmStatisticsProvider._({
    required NmStatisticsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'nmStatisticsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nmStatisticsHash();

  @override
  String toString() {
    return r'nmStatisticsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  NmStatistics create() => NmStatistics();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkManagerDeviceStatistics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkManagerDeviceStatistics>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NmStatisticsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nmStatisticsHash() => r'15996dbae75aa683ec386c660a91c5bcd8df050c';

final class NmStatisticsFamily extends $Family
    with
        $ClassFamilyOverride<
          NmStatistics,
          NetworkManagerDeviceStatistics,
          NetworkManagerDeviceStatistics,
          NetworkManagerDeviceStatistics,
          String
        > {
  const NmStatisticsFamily._()
    : super(
        retry: null,
        name: r'nmStatisticsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NmStatisticsProvider call(String hwAddress) =>
      NmStatisticsProvider._(argument: hwAddress, from: this);

  @override
  String toString() => r'nmStatisticsProvider';
}

abstract class _$NmStatistics
    extends $Notifier<NetworkManagerDeviceStatistics> {
  late final _$args = ref.$arg as String;
  String get hwAddress => _$args;

  NetworkManagerDeviceStatistics build(String hwAddress);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref
            as $Ref<
              NetworkManagerDeviceStatistics,
              NetworkManagerDeviceStatistics
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                NetworkManagerDeviceStatistics,
                NetworkManagerDeviceStatistics
              >,
              NetworkManagerDeviceStatistics,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
