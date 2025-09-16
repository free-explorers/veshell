// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bluetooth_device.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BluetoothDeviceState)
const bluetoothDeviceStateProvider = BluetoothDeviceStateFamily._();

final class BluetoothDeviceStateProvider
    extends $NotifierProvider<BluetoothDeviceState, BluetoothDevice?> {
  const BluetoothDeviceStateProvider._({
    required BluetoothDeviceStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bluetoothDeviceStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bluetoothDeviceStateHash();

  @override
  String toString() {
    return r'bluetoothDeviceStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BluetoothDeviceState create() => BluetoothDeviceState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BluetoothDevice? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BluetoothDevice?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BluetoothDeviceStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bluetoothDeviceStateHash() =>
    r'2550705473bf8663fbdeb9a789314371228b220c';

final class BluetoothDeviceStateFamily extends $Family
    with
        $ClassFamilyOverride<
          BluetoothDeviceState,
          BluetoothDevice?,
          BluetoothDevice?,
          BluetoothDevice?,
          String
        > {
  const BluetoothDeviceStateFamily._()
    : super(
        retry: null,
        name: r'bluetoothDeviceStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BluetoothDeviceStateProvider call(String address) =>
      BluetoothDeviceStateProvider._(argument: address, from: this);

  @override
  String toString() => r'bluetoothDeviceStateProvider';
}

abstract class _$BluetoothDeviceState extends $Notifier<BluetoothDevice?> {
  late final _$args = ref.$arg as String;
  String get address => _$args;

  BluetoothDevice? build(String address);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<BluetoothDevice?, BluetoothDevice?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BluetoothDevice?, BluetoothDevice?>,
              BluetoothDevice?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
