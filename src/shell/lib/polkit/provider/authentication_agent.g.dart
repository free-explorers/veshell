// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authentication_agent.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PolkitAuthenticationAgentState)
const polkitAuthenticationAgentStateProvider =
    PolkitAuthenticationAgentStateProvider._();

final class PolkitAuthenticationAgentStateProvider
    extends
        $AsyncNotifierProvider<
          PolkitAuthenticationAgentState,
          OrgFreedesktopPolicyKit1AuthenticationAgent
        > {
  const PolkitAuthenticationAgentStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'polkitAuthenticationAgentStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$polkitAuthenticationAgentStateHash();

  @$internal
  @override
  PolkitAuthenticationAgentState create() => PolkitAuthenticationAgentState();
}

String _$polkitAuthenticationAgentStateHash() =>
    r'07129c0643123d79e4a2e81e8b505052357acbb9';

abstract class _$PolkitAuthenticationAgentState
    extends $AsyncNotifier<OrgFreedesktopPolicyKit1AuthenticationAgent> {
  FutureOr<OrgFreedesktopPolicyKit1AuthenticationAgent> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<OrgFreedesktopPolicyKit1AuthenticationAgent>,
              OrgFreedesktopPolicyKit1AuthenticationAgent
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<OrgFreedesktopPolicyKit1AuthenticationAgent>,
                OrgFreedesktopPolicyKit1AuthenticationAgent
              >,
              AsyncValue<OrgFreedesktopPolicyKit1AuthenticationAgent>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
