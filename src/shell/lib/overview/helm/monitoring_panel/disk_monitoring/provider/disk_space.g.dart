// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'disk_space.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DiskSpaceState)
const diskSpaceStateProvider = DiskSpaceStateProvider._();

final class DiskSpaceStateProvider
    extends $NotifierProvider<DiskSpaceState, List<Disk>> {
  const DiskSpaceStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diskSpaceStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diskSpaceStateHash();

  @$internal
  @override
  DiskSpaceState create() => DiskSpaceState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Disk> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Disk>>(value),
    );
  }
}

String _$diskSpaceStateHash() => r'7c4b0008b343ccb46f4875ccec0398459009ae7f';

abstract class _$DiskSpaceState extends $Notifier<List<Disk>> {
  List<Disk> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<Disk>, List<Disk>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Disk>, List<Disk>>,
              List<Disk>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
