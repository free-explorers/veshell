// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dev_tools_enabled.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DevToolsEnabled)
const devToolsEnabledProvider = DevToolsEnabledProvider._();

final class DevToolsEnabledProvider
    extends $NotifierProvider<DevToolsEnabled, bool> {
  const DevToolsEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devToolsEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devToolsEnabledHash();

  @$internal
  @override
  DevToolsEnabled create() => DevToolsEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devToolsEnabledHash() => r'17144b527bb02ca775a511160a580eadb0cff046';

abstract class _$DevToolsEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
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
