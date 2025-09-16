// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VeshellTheme)
const veshellThemeProvider = VeshellThemeProvider._();

final class VeshellThemeProvider
    extends $NotifierProvider<VeshellTheme, (ThemeData, ThemeData)> {
  const VeshellThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'veshellThemeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$veshellThemeHash();

  @$internal
  @override
  VeshellTheme create() => VeshellTheme();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue((ThemeData, ThemeData) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<(ThemeData, ThemeData)>(value),
    );
  }
}

String _$veshellThemeHash() => r'32cff587c553471b7949b0ad8ce7d0d9d7a9c87d';

abstract class _$VeshellTheme extends $Notifier<(ThemeData, ThemeData)> {
  (ThemeData, ThemeData) build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<(ThemeData, ThemeData), (ThemeData, ThemeData)>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<(ThemeData, ThemeData), (ThemeData, ThemeData)>,
              (ThemeData, ThemeData),
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
