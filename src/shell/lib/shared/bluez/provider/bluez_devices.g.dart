// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bluez_devices.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BluezDevices)
const bluezDevicesProvider = BluezDevicesProvider._();

final class BluezDevicesProvider
    extends $AsyncNotifierProvider<BluezDevices, ISet<String>> {
  const BluezDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bluezDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bluezDevicesHash();

  @$internal
  @override
  BluezDevices create() => BluezDevices();
}

String _$bluezDevicesHash() => r'27574a46d9d37ad5ab96b03f62b6f763febdadb3';

abstract class _$BluezDevices extends $AsyncNotifier<ISet<String>> {
  FutureOr<ISet<String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<ISet<String>>, ISet<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ISet<String>>, ISet<String>>,
              AsyncValue<ISet<String>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
