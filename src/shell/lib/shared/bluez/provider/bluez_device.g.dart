// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bluez_device.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BluezDevice)
const bluezDeviceProvider = BluezDeviceFamily._();

final class BluezDeviceProvider
    extends $NotifierProvider<BluezDevice, BlueZDevice?> {
  const BluezDeviceProvider._({
    required BluezDeviceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bluezDeviceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bluezDeviceHash();

  @override
  String toString() {
    return r'bluezDeviceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BluezDevice create() => BluezDevice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlueZDevice? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlueZDevice?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BluezDeviceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bluezDeviceHash() => r'8c5117b9b9a733c9164ecb2495d17aab8bad9513';

final class BluezDeviceFamily extends $Family
    with
        $ClassFamilyOverride<
          BluezDevice,
          BlueZDevice?,
          BlueZDevice?,
          BlueZDevice?,
          String
        > {
  const BluezDeviceFamily._()
    : super(
        retry: null,
        name: r'bluezDeviceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BluezDeviceProvider call(String address) =>
      BluezDeviceProvider._(argument: address, from: this);

  @override
  String toString() => r'bluezDeviceProvider';
}

abstract class _$BluezDevice extends $Notifier<BlueZDevice?> {
  late final _$args = ref.$arg as String;
  String get address => _$args;

  BlueZDevice? build(String address);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<BlueZDevice?, BlueZDevice?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BlueZDevice?, BlueZDevice?>,
              BlueZDevice?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
