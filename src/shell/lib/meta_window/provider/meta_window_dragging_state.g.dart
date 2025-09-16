// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_window_dragging_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MetaWindowDraggingState)
const metaWindowDraggingStateProvider = MetaWindowDraggingStateFamily._();

final class MetaWindowDraggingStateProvider
    extends $NotifierProvider<MetaWindowDraggingState, bool> {
  const MetaWindowDraggingStateProvider._({
    required MetaWindowDraggingStateFamily super.from,
    required MetaWindowId super.argument,
  }) : super(
         retry: null,
         name: r'metaWindowDraggingStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$metaWindowDraggingStateHash();

  @override
  String toString() {
    return r'metaWindowDraggingStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MetaWindowDraggingState create() => MetaWindowDraggingState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MetaWindowDraggingStateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$metaWindowDraggingStateHash() =>
    r'359a90a3bb941d36638dfa0f8bbee8734d3b8ffd';

final class MetaWindowDraggingStateFamily extends $Family
    with
        $ClassFamilyOverride<
          MetaWindowDraggingState,
          bool,
          bool,
          bool,
          MetaWindowId
        > {
  const MetaWindowDraggingStateFamily._()
    : super(
        retry: null,
        name: r'metaWindowDraggingStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MetaWindowDraggingStateProvider call(MetaWindowId metaWindowId) =>
      MetaWindowDraggingStateProvider._(argument: metaWindowId, from: this);

  @override
  String toString() => r'metaWindowDraggingStateProvider';
}

abstract class _$MetaWindowDraggingState extends $Notifier<bool> {
  late final _$args = ref.$arg as MetaWindowId;
  MetaWindowId get metaWindowId => _$args;

  bool build(MetaWindowId metaWindowId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
