// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subsurface_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

@ProviderFor(SubsurfaceState)
const subsurfaceStateProvider = SubsurfaceStateFamily._();

final class SubsurfaceStateProvider
    extends $NotifierProvider<SubsurfaceState, Subsurface> {
  const SubsurfaceStateProvider._(
      {required SubsurfaceStateFamily super.from,
      required SurfaceId super.argument})
      : super(
          retry: null,
          name: r'subsurfaceStateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$subsurfaceStateHash();

  @override
  String toString() {
    return r'subsurfaceStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SubsurfaceState create() => SubsurfaceState();

  @$internal
  @override
  $NotifierProviderElement<SubsurfaceState, Subsurface> $createElement(
          $ProviderPointer pointer) =>
      $NotifierProviderElement(pointer);

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Subsurface value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $ValueProvider<Subsurface>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SubsurfaceStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subsurfaceStateHash() => r'bca7b2b8e67a471ae7ebcdf4cc2d3d7bf6337b2d';

final class SubsurfaceStateFamily extends $Family
    with
        $ClassFamilyOverride<SubsurfaceState, Subsurface, Subsurface,
            Subsurface, SurfaceId> {
  const SubsurfaceStateFamily._()
      : super(
          retry: null,
          name: r'subsurfaceStateProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  SubsurfaceStateProvider call(
    SurfaceId surfaceId,
  ) =>
      SubsurfaceStateProvider._(argument: surfaceId, from: this);

  @override
  String toString() => r'subsurfaceStateProvider';
}

abstract class _$SubsurfaceState extends $Notifier<Subsurface> {
  late final _$args = ref.$arg as SurfaceId;
  SurfaceId get surfaceId => _$args;

  Subsurface build(
    SurfaceId surfaceId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<Subsurface>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Subsurface>, Subsurface, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
