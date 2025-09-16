// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_window_resizing_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MetaWindowResizingState)
const metaWindowResizingStateProvider = MetaWindowResizingStateFamily._();

final class MetaWindowResizingStateProvider
    extends $NotifierProvider<MetaWindowResizingState, ResizeEdge?> {
  const MetaWindowResizingStateProvider._({
    required MetaWindowResizingStateFamily super.from,
    required MetaWindowId super.argument,
  }) : super(
         retry: null,
         name: r'metaWindowResizingStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$metaWindowResizingStateHash();

  @override
  String toString() {
    return r'metaWindowResizingStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MetaWindowResizingState create() => MetaWindowResizingState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResizeEdge? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResizeEdge?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MetaWindowResizingStateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$metaWindowResizingStateHash() =>
    r'3b7a053f189a202ae9082ee76786ed618ef5e844';

final class MetaWindowResizingStateFamily extends $Family
    with
        $ClassFamilyOverride<
          MetaWindowResizingState,
          ResizeEdge?,
          ResizeEdge?,
          ResizeEdge?,
          MetaWindowId
        > {
  const MetaWindowResizingStateFamily._()
    : super(
        retry: null,
        name: r'metaWindowResizingStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MetaWindowResizingStateProvider call(MetaWindowId metaWindowId) =>
      MetaWindowResizingStateProvider._(argument: metaWindowId, from: this);

  @override
  String toString() => r'metaWindowResizingStateProvider';
}

abstract class _$MetaWindowResizingState extends $Notifier<ResizeEdge?> {
  late final _$args = ref.$arg as MetaWindowId;
  MetaWindowId get metaWindowId => _$args;

  ResizeEdge? build(MetaWindowId metaWindowId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<ResizeEdge?, ResizeEdge?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ResizeEdge?, ResizeEdge?>,
              ResizeEdge?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
