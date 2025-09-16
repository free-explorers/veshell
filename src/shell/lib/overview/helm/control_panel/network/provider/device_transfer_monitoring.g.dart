// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_transfer_monitoring.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DeviceTransferMonitoringState)
const deviceTransferMonitoringStateProvider =
    DeviceTransferMonitoringStateFamily._();

final class DeviceTransferMonitoringStateProvider
    extends
        $NotifierProvider<
          DeviceTransferMonitoringState,
          DeviceTransferMonitoring
        > {
  const DeviceTransferMonitoringStateProvider._({
    required DeviceTransferMonitoringStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'deviceTransferMonitoringStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$deviceTransferMonitoringStateHash();

  @override
  String toString() {
    return r'deviceTransferMonitoringStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DeviceTransferMonitoringState create() => DeviceTransferMonitoringState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceTransferMonitoring value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceTransferMonitoring>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DeviceTransferMonitoringStateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$deviceTransferMonitoringStateHash() =>
    r'08761865721849751197f94a74e60c11398cb6d9';

final class DeviceTransferMonitoringStateFamily extends $Family
    with
        $ClassFamilyOverride<
          DeviceTransferMonitoringState,
          DeviceTransferMonitoring,
          DeviceTransferMonitoring,
          DeviceTransferMonitoring,
          String
        > {
  const DeviceTransferMonitoringStateFamily._()
    : super(
        retry: null,
        name: r'deviceTransferMonitoringStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DeviceTransferMonitoringStateProvider call(String address) =>
      DeviceTransferMonitoringStateProvider._(argument: address, from: this);

  @override
  String toString() => r'deviceTransferMonitoringStateProvider';
}

abstract class _$DeviceTransferMonitoringState
    extends $Notifier<DeviceTransferMonitoring> {
  late final _$args = ref.$arg as String;
  String get address => _$args;

  DeviceTransferMonitoring build(String address);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<DeviceTransferMonitoring, DeviceTransferMonitoring>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DeviceTransferMonitoring, DeviceTransferMonitoring>,
              DeviceTransferMonitoring,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
