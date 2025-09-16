// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_window_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MetaWindowManager)
const metaWindowManagerProvider = MetaWindowManagerProvider._();

final class MetaWindowManagerProvider
    extends $NotifierProvider<MetaWindowManager, ISet<MetaWindowId>> {
  const MetaWindowManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'metaWindowManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$metaWindowManagerHash();

  @$internal
  @override
  MetaWindowManager create() => MetaWindowManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISet<MetaWindowId> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISet<MetaWindowId>>(value),
    );
  }
}

String _$metaWindowManagerHash() => r'15e00425878b257923010af650f4a6494a2e7cd6';

abstract class _$MetaWindowManager extends $Notifier<ISet<MetaWindowId>> {
  ISet<MetaWindowId> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ISet<MetaWindowId>, ISet<MetaWindowId>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ISet<MetaWindowId>, ISet<MetaWindowId>>,
              ISet<MetaWindowId>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
