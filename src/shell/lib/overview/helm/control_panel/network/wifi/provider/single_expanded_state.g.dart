// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'single_expanded_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SingleExpanded)
const singleExpandedProvider = SingleExpandedFamily._();

final class SingleExpandedProvider
    extends $NotifierProvider<SingleExpanded, String?> {
  const SingleExpandedProvider._({
    required SingleExpandedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'singleExpandedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$singleExpandedHash();

  @override
  String toString() {
    return r'singleExpandedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SingleExpanded create() => SingleExpanded();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SingleExpandedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$singleExpandedHash() => r'7ebd35615a6bad0b09e48f90b800578240ac69ce';

final class SingleExpandedFamily extends $Family
    with
        $ClassFamilyOverride<
          SingleExpanded,
          String?,
          String?,
          String?,
          String
        > {
  const SingleExpandedFamily._()
    : super(
        retry: null,
        name: r'singleExpandedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SingleExpandedProvider call(String key) =>
      SingleExpandedProvider._(argument: key, from: this);

  @override
  String toString() => r'singleExpandedProvider';
}

abstract class _$SingleExpanded extends $Notifier<String?> {
  late final _$args = ref.$arg as String;
  String get key => _$args;

  String? build(String key);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
