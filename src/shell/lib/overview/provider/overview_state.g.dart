// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overview_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OverviewState)
const overviewStateProvider = OverviewStateFamily._();

final class OverviewStateProvider
    extends $NotifierProvider<OverviewState, Overview> {
  const OverviewStateProvider._({
    required OverviewStateFamily super.from,
    required ScreenId super.argument,
  }) : super(
         retry: null,
         name: r'overviewStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$overviewStateHash();

  @override
  String toString() {
    return r'overviewStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  OverviewState create() => OverviewState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Overview value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Overview>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OverviewStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$overviewStateHash() => r'47e4d3df61c5d36ecc58ae83471c99e170b3059b';

final class OverviewStateFamily extends $Family
    with
        $ClassFamilyOverride<
          OverviewState,
          Overview,
          Overview,
          Overview,
          ScreenId
        > {
  const OverviewStateFamily._()
    : super(
        retry: null,
        name: r'overviewStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  OverviewStateProvider call(ScreenId screenId) =>
      OverviewStateProvider._(argument: screenId, from: this);

  @override
  String toString() => r'overviewStateProvider';
}

abstract class _$OverviewState extends $Notifier<Overview> {
  late final _$args = ref.$arg as ScreenId;
  ScreenId get screenId => _$args;

  Overview build(ScreenId screenId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<Overview, Overview>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Overview, Overview>,
              Overview,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
