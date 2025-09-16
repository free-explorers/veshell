// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'environment_variables.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EnvironmentVariables)
const environmentVariablesProvider = EnvironmentVariablesProvider._();

final class EnvironmentVariablesProvider
    extends $NotifierProvider<EnvironmentVariables, IMap<String, String>> {
  const EnvironmentVariablesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'environmentVariablesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$environmentVariablesHash();

  @$internal
  @override
  EnvironmentVariables create() => EnvironmentVariables();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IMap<String, String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IMap<String, String>>(value),
    );
  }
}

String _$environmentVariablesHash() =>
    r'6da8dd1acd96864b684fa334cc0da4f49ebd7dc2';

abstract class _$EnvironmentVariables extends $Notifier<IMap<String, String>> {
  IMap<String, String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<IMap<String, String>, IMap<String, String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<IMap<String, String>, IMap<String, String>>,
              IMap<String, String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
