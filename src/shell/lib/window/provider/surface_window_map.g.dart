// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'surface_window_map.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SurfaceWindowMap)
const surfaceWindowMapProvider = SurfaceWindowMapProvider._();

final class SurfaceWindowMapProvider
    extends $NotifierProvider<SurfaceWindowMap, IMap<SurfaceId, WindowId>> {
  const SurfaceWindowMapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'surfaceWindowMapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$surfaceWindowMapHash();

  @$internal
  @override
  SurfaceWindowMap create() => SurfaceWindowMap();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IMap<SurfaceId, WindowId> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IMap<SurfaceId, WindowId>>(value),
    );
  }
}

String _$surfaceWindowMapHash() => r'706bab79411aa7fe00b7697d1a1ba9cd44164aca';

abstract class _$SurfaceWindowMap extends $Notifier<IMap<SurfaceId, WindowId>> {
  IMap<SurfaceId, WindowId> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<IMap<SurfaceId, WindowId>, IMap<SurfaceId, WindowId>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<IMap<SurfaceId, WindowId>, IMap<SurfaceId, WindowId>>,
              IMap<SurfaceId, WindowId>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
