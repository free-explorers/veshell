// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_popup_for_id.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MetaPopupForId)
const metaPopupForIdProvider = MetaPopupForIdFamily._();

final class MetaPopupForIdProvider
    extends $NotifierProvider<MetaPopupForId, ISet<MetaPopupId>> {
  const MetaPopupForIdProvider._({
    required MetaPopupForIdFamily super.from,
    required MetaWindowId super.argument,
  }) : super(
         retry: null,
         name: r'metaPopupForIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$metaPopupForIdHash();

  @override
  String toString() {
    return r'metaPopupForIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MetaPopupForId create() => MetaPopupForId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISet<MetaPopupId> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISet<MetaPopupId>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MetaPopupForIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$metaPopupForIdHash() => r'907685592f2f42aa2ecc2b7ea2e71516a82b7242';

final class MetaPopupForIdFamily extends $Family
    with
        $ClassFamilyOverride<
          MetaPopupForId,
          ISet<MetaPopupId>,
          ISet<MetaPopupId>,
          ISet<MetaPopupId>,
          MetaWindowId
        > {
  const MetaPopupForIdFamily._()
    : super(
        retry: null,
        name: r'metaPopupForIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MetaPopupForIdProvider call(MetaWindowId parentId) =>
      MetaPopupForIdProvider._(argument: parentId, from: this);

  @override
  String toString() => r'metaPopupForIdProvider';
}

abstract class _$MetaPopupForId extends $Notifier<ISet<MetaPopupId>> {
  late final _$args = ref.$arg as MetaWindowId;
  MetaWindowId get parentId => _$args;

  ISet<MetaPopupId> build(MetaWindowId parentId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<ISet<MetaPopupId>, ISet<MetaPopupId>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ISet<MetaPopupId>, ISet<MetaPopupId>>,
              ISet<MetaPopupId>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
