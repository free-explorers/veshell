// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matching_engine.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// MatchingEngine is responsible for matching surfaces to windows.

@ProviderFor(MatchingEngine)
const matchingEngineProvider = MatchingEngineProvider._();

/// MatchingEngine is responsible for matching surfaces to windows.
final class MatchingEngineProvider
    extends $NotifierProvider<MatchingEngine, IMap<MetaWindowId, WindowId>> {
  /// MatchingEngine is responsible for matching surfaces to windows.
  const MatchingEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matchingEngineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matchingEngineHash();

  @$internal
  @override
  MatchingEngine create() => MatchingEngine();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IMap<MetaWindowId, WindowId> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IMap<MetaWindowId, WindowId>>(value),
    );
  }
}

String _$matchingEngineHash() => r'c642acd626ba601eeff444641b81b264164ea58d';

/// MatchingEngine is responsible for matching surfaces to windows.

abstract class _$MatchingEngine
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
