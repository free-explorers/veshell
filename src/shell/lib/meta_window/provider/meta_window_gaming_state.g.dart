// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_window_gaming_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MetaWindowGamingState)
const metaWindowGamingStateProvider = MetaWindowGamingStateFamily._();

final class MetaWindowGamingStateProvider
    extends $NotifierProvider<MetaWindowGamingState, MetaWindowGamingStatus> {
  const MetaWindowGamingStateProvider._({
    required MetaWindowGamingStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'metaWindowGamingStateProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$metaWindowGamingStateHash();

  @override
  String toString() {
    return r'metaWindowGamingStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MetaWindowGamingState create() => MetaWindowGamingState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MetaWindowGamingStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MetaWindowGamingStatus>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MetaWindowGamingStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$metaWindowGamingStateHash() =>
    r'900a28bda71269ed490bcce11e447bd42cead000';

final class MetaWindowGamingStateFamily extends $Family
    with
        $ClassFamilyOverride<
          MetaWindowGamingState,
          MetaWindowGamingStatus,
          MetaWindowGamingStatus,
          MetaWindowGamingStatus,
          String
        > {
  const MetaWindowGamingStateFamily._()
    : super(
        retry: null,
        name: r'metaWindowGamingStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  MetaWindowGamingStateProvider call(String metaWindowId) =>
      MetaWindowGamingStateProvider._(argument: metaWindowId, from: this);

  @override
  String toString() => r'metaWindowGamingStateProvider';
}

abstract class _$MetaWindowGamingState
    extends $Notifier<MetaWindowGamingStatus> {
  late final _$args = ref.$arg as String;
  String get metaWindowId => _$args;

  MetaWindowGamingStatus build(String metaWindowId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<MetaWindowGamingStatus, MetaWindowGamingStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MetaWindowGamingStatus, MetaWindowGamingStatus>,
              MetaWindowGamingStatus,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
