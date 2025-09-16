// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focused_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provide the current Focused screen

@ProviderFor(FocusedScreen)
const focusedScreenProvider = FocusedScreenProvider._();

/// Provide the current Focused screen
final class FocusedScreenProvider
    extends $NotifierProvider<FocusedScreen, ScreenId> {
  /// Provide the current Focused screen
  const FocusedScreenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'focusedScreenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$focusedScreenHash();

  @$internal
  @override
  FocusedScreen create() => FocusedScreen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScreenId value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScreenId>(value),
    );
  }
}

String _$focusedScreenHash() => r'b29bdbe19b8a7d773effe5730384f355cab72d99';

/// Provide the current Focused screen

abstract class _$FocusedScreen extends $Notifier<ScreenId> {
  ScreenId build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ScreenId, ScreenId>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ScreenId, ScreenId>,
              ScreenId,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
