// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'surface.manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

@ProviderFor(SurfaceManager)
const surfaceManagerProvider = SurfaceManagerProvider._();

final class SurfaceManagerProvider
    extends $NotifierProvider<SurfaceManager, SurfaceManagerState> {
  const SurfaceManagerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'surfaceManagerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$surfaceManagerHash();

  @$internal
  @override
  SurfaceManager create() => SurfaceManager();

  @$internal
  @override
  $NotifierProviderElement<SurfaceManager, SurfaceManagerState> $createElement(
          $ProviderPointer pointer) =>
      $NotifierProviderElement(pointer);

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SurfaceManagerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $ValueProvider<SurfaceManagerState>(value),
    );
  }
}

String _$surfaceManagerHash() => r'7ec84d60c829f91e83852a17b8c4cdb5f56acc8c';

abstract class _$SurfaceManager extends $Notifier<SurfaceManagerState> {
  SurfaceManagerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SurfaceManagerState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<SurfaceManagerState>,
        SurfaceManagerState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
