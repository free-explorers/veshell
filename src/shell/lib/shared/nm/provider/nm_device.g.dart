// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nm_device.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NmDevice)
const nmDeviceProvider = NmDeviceFamily._();

final class NmDeviceProvider
    extends $NotifierProvider<NmDevice, NetworkManagerDevice> {
  const NmDeviceProvider._({
    required NmDeviceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'nmDeviceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nmDeviceHash();

  @override
  String toString() {
    return r'nmDeviceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  NmDevice create() => NmDevice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkManagerDevice value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkManagerDevice>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NmDeviceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nmDeviceHash() => r'746569efac7d38aca410cb5906fe6ca2d08bf177';

final class NmDeviceFamily extends $Family
    with
        $ClassFamilyOverride<
          NmDevice,
          NetworkManagerDevice,
          NetworkManagerDevice,
          NetworkManagerDevice,
          String
        > {
  const NmDeviceFamily._()
    : super(
        retry: null,
        name: r'nmDeviceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NmDeviceProvider call(String hwAddress) =>
      NmDeviceProvider._(argument: hwAddress, from: this);

  @override
  String toString() => r'nmDeviceProvider';
}

abstract class _$NmDevice extends $Notifier<NetworkManagerDevice> {
  late final _$args = ref.$arg as String;
  String get hwAddress => _$args;

  NetworkManagerDevice build(String hwAddress);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<NetworkManagerDevice, NetworkManagerDevice>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NetworkManagerDevice, NetworkManagerDevice>,
              NetworkManagerDevice,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
