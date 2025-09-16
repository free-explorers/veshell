// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'surface.manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$surfaceManagerHash();

  @$internal
  @override
  SurfaceManager create() => SurfaceManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SurfaceManagerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SurfaceManagerState>(value),
    );
  }
}

String _$surfaceManagerHash() => r'44c910413b0c1022ff7be5890131d668f6280bd8';

abstract class _$SurfaceManager extends $Notifier<SurfaceManagerState> {
  SurfaceManagerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SurfaceManagerState, SurfaceManagerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SurfaceManagerState, SurfaceManagerState>,
              SurfaceManagerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
