// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nm_devices.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NmDevices)
const nmDevicesProvider = NmDevicesProvider._();

final class NmDevicesProvider
    extends $AsyncNotifierProvider<NmDevices, ISet<String>> {
  const NmDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nmDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nmDevicesHash();

  @$internal
  @override
  NmDevices create() => NmDevices();
}

String _$nmDevicesHash() => r'd6c07e281e44513f50b67ac6b9b811a93847c7a7';

abstract class _$NmDevices extends $AsyncNotifier<ISet<String>> {
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
