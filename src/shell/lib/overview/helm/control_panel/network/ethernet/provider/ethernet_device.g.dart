// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ethernet_device.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EthernetDeviceState)
const ethernetDeviceStateProvider = EthernetDeviceStateFamily._();

final class EthernetDeviceStateProvider
    extends $NotifierProvider<EthernetDeviceState, EthernetDevice> {
  const EthernetDeviceStateProvider._({
    required EthernetDeviceStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ethernetDeviceStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ethernetDeviceStateHash();

  @override
  String toString() {
    return r'ethernetDeviceStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EthernetDeviceState create() => EthernetDeviceState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EthernetDevice value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EthernetDevice>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EthernetDeviceStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ethernetDeviceStateHash() =>
    r'164a3ab2cd7a6f275879fcf4d53ff8a36ea07e6f';

final class EthernetDeviceStateFamily extends $Family
    with
        $ClassFamilyOverride<
          EthernetDeviceState,
          EthernetDevice,
          EthernetDevice,
          EthernetDevice,
          String
        > {
  const EthernetDeviceStateFamily._()
    : super(
        retry: null,
        name: r'ethernetDeviceStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EthernetDeviceStateProvider call(String address) =>
      EthernetDeviceStateProvider._(argument: address, from: this);

  @override
  String toString() => r'ethernetDeviceStateProvider';
}

abstract class _$EthernetDeviceState extends $Notifier<EthernetDevice> {
  late final _$args = ref.$arg as String;
  String get address => _$args;

  EthernetDevice build(String address);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<EthernetDevice, EthernetDevice>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EthernetDevice, EthernetDevice>,
              EthernetDevice,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
