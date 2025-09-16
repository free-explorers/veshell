// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bluetooth_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BluetoothManager)
const bluetoothManagerProvider = BluetoothManagerProvider._();

final class BluetoothManagerProvider
    extends $AsyncNotifierProvider<BluetoothManager, BluetoothManagerState> {
  const BluetoothManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bluetoothManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bluetoothManagerHash();

  @$internal
  @override
  BluetoothManager create() => BluetoothManager();
}

String _$bluetoothManagerHash() => r'fb986d7decef0f3d3b57d69c364436784e2084af';

abstract class _$BluetoothManager
    extends $AsyncNotifier<BluetoothManagerState> {
  FutureOr<BluetoothManagerState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<BluetoothManagerState>, BluetoothManagerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<BluetoothManagerState>,
                BluetoothManagerState
              >,
              AsyncValue<BluetoothManagerState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
