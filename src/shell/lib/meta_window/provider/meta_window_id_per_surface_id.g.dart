// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_window_id_per_surface_id.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MetaWindowIdPerSurfaceId)
const metaWindowIdPerSurfaceIdProvider = MetaWindowIdPerSurfaceIdFamily._();

final class MetaWindowIdPerSurfaceIdProvider
    extends $NotifierProvider<MetaWindowIdPerSurfaceId, MetaWindowId?> {
  const MetaWindowIdPerSurfaceIdProvider._({
    required MetaWindowIdPerSurfaceIdFamily super.from,
    required SurfaceId super.argument,
  }) : super(
         retry: null,
         name: r'metaWindowIdPerSurfaceIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$metaWindowIdPerSurfaceIdHash();

  @override
  String toString() {
    return r'metaWindowIdPerSurfaceIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MetaWindowIdPerSurfaceId create() => MetaWindowIdPerSurfaceId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MetaWindowId? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MetaWindowId?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MetaWindowIdPerSurfaceIdProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$metaWindowIdPerSurfaceIdHash() =>
    r'aa7e2aa58b84e5d51f5c0296e4105568d9ae2823';

final class MetaWindowIdPerSurfaceIdFamily extends $Family
    with
        $ClassFamilyOverride<
          MetaWindowIdPerSurfaceId,
          MetaWindowId?,
          MetaWindowId?,
          MetaWindowId?,
          SurfaceId
        > {
  const MetaWindowIdPerSurfaceIdFamily._()
    : super(
        retry: null,
        name: r'metaWindowIdPerSurfaceIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MetaWindowIdPerSurfaceIdProvider call(SurfaceId surfaceId) =>
      MetaWindowIdPerSurfaceIdProvider._(argument: surfaceId, from: this);

  @override
  String toString() => r'metaWindowIdPerSurfaceIdProvider';
}

abstract class _$MetaWindowIdPerSurfaceId extends $Notifier<MetaWindowId?> {
  late final _$args = ref.$arg as SurfaceId;
  SurfaceId get surfaceId => _$args;

  MetaWindowId? build(SurfaceId surfaceId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<MetaWindowId?, MetaWindowId?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MetaWindowId?, MetaWindowId?>,
              MetaWindowId?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
