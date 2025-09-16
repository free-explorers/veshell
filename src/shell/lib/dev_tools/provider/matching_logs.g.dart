// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matching_logs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MatchingLogs)
const matchingLogsProvider = MatchingLogsProvider._();

final class MatchingLogsProvider
    extends $NotifierProvider<MatchingLogs, List<String>> {
  const MatchingLogsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matchingLogsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matchingLogsHash();

  @$internal
  @override
  MatchingLogs create() => MatchingLogs();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$matchingLogsHash() => r'06c89463a437930787d375cbb1457235e5132fe7';

abstract class _$MatchingLogs extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
