// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_popup_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MetaPopupState)
const metaPopupStateProvider = MetaPopupStateFamily._();

final class MetaPopupStateProvider
    extends $NotifierProvider<MetaPopupState, MetaPopup> {
  const MetaPopupStateProvider._({
    required MetaPopupStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'metaPopupStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$metaPopupStateHash();

  @override
  String toString() {
    return r'metaPopupStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MetaPopupState create() => MetaPopupState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MetaPopup value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MetaPopup>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MetaPopupStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$metaPopupStateHash() => r'61b89ad35ad08ba055493998805d4ece788beeb1';

final class MetaPopupStateFamily extends $Family
    with
        $ClassFamilyOverride<
          MetaPopupState,
          MetaPopup,
          MetaPopup,
          MetaPopup,
          String
        > {
  const MetaPopupStateFamily._()
    : super(
        retry: null,
        name: r'metaPopupStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MetaPopupStateProvider call(String id) =>
      MetaPopupStateProvider._(argument: id, from: this);

  @override
  String toString() => r'metaPopupStateProvider';
}

abstract class _$MetaPopupState extends $Notifier<MetaPopup> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  MetaPopup build(String id);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<MetaPopup, MetaPopup>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MetaPopup, MetaPopup>,
              MetaPopup,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
