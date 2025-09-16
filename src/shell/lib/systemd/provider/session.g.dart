// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Session)
const sessionProvider = SessionProvider._();

final class SessionProvider
    extends $NotifierProvider<Session, SystemdSessionManager> {
  const SessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionHash();

  @$internal
  @override
  Session create() => Session();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemdSessionManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemdSessionManager>(value),
    );
  }
}

String _$sessionHash() => r'70a86d87c736a7b61e0d8b815495f4c8603a2cbd';

abstract class _$Session extends $Notifier<SystemdSessionManager> {
  SystemdSessionManager build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SystemdSessionManager, SystemdSessionManager>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SystemdSessionManager, SystemdSessionManager>,
              SystemdSessionManager,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
