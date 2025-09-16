// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wl_surface_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

@ProviderFor(WlSurfaceState)
const wlSurfaceStateProvider = WlSurfaceStateFamily._();

final class WlSurfaceStateProvider
    extends $NotifierProvider<WlSurfaceState, WlSurface> {
  const WlSurfaceStateProvider._(
      {required WlSurfaceStateFamily super.from,
      required SurfaceId super.argument})
      : super(
          retry: null,
          name: r'wlSurfaceStateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$wlSurfaceStateHash();

  @override
  String toString() {
    return r'wlSurfaceStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WlSurfaceState create() => WlSurfaceState();

  @$internal
  @override
  $NotifierProviderElement<WlSurfaceState, WlSurface> $createElement(
          $ProviderPointer pointer) =>
      $NotifierProviderElement(pointer);

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WlSurface value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $ValueProvider<WlSurface>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WlSurfaceStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$wlSurfaceStateHash() => r'5bae79b03e1602dad87d57b6cd90c4a009769c6a';

final class WlSurfaceStateFamily extends $Family
    with
        $ClassFamilyOverride<WlSurfaceState, WlSurface, WlSurface, WlSurface,
            SurfaceId> {
  const WlSurfaceStateFamily._()
      : super(
          retry: null,
          name: r'wlSurfaceStateProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  WlSurfaceStateProvider call(
    SurfaceId surfaceId,
  ) =>
      WlSurfaceStateProvider._(argument: surfaceId, from: this);

  @override
  String toString() => r'wlSurfaceStateProvider';
}

abstract class _$WlSurfaceState extends $Notifier<WlSurface> {
  late final _$args = ref.$arg as SurfaceId;
  SurfaceId get surfaceId => _$args;

  WlSurface build(
    SurfaceId surfaceId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<WlSurface>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<WlSurface>,
        WlSurface, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
