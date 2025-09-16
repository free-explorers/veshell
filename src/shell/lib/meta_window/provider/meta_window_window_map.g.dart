// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_window_window_map.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MetaWindowWindowMap)
const metaWindowWindowMapProvider = MetaWindowWindowMapProvider._();

final class MetaWindowWindowMapProvider
    extends
        $NotifierProvider<MetaWindowWindowMap, IMap<MetaWindowId, WindowId>> {
  const MetaWindowWindowMapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'metaWindowWindowMapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$metaWindowWindowMapHash();

  @$internal
  @override
  MetaWindowWindowMap create() => MetaWindowWindowMap();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IMap<MetaWindowId, WindowId> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IMap<MetaWindowId, WindowId>>(value),
    );
  }
}

String _$metaWindowWindowMapHash() =>
    r'ecffaa148f7da05f7350ee4f40a5f0227b9a3c89';

abstract class _$MetaWindowWindowMap
    extends $Notifier<IMap<MetaWindowId, WindowId>> {
  IMap<MetaWindowId, WindowId> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<IMap<MetaWindowId, WindowId>, IMap<MetaWindowId, WindowId>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                IMap<MetaWindowId, WindowId>,
                IMap<MetaWindowId, WindowId>
              >,
              IMap<MetaWindowId, WindowId>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
