// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'icon_themes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(iconThemes)
const iconThemesProvider = IconThemesProvider._();

final class IconThemesProvider
    extends
        $FunctionalProvider<
          AsyncValue<FreedesktopIconTheme>,
          FreedesktopIconTheme,
          FutureOr<FreedesktopIconTheme>
        >
    with
        $FutureModifier<FreedesktopIconTheme>,
        $FutureProvider<FreedesktopIconTheme> {
  const IconThemesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'iconThemesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$iconThemesHash();

  @$internal
  @override
  $FutureProviderElement<FreedesktopIconTheme> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FreedesktopIconTheme> create(Ref ref) {
    return iconThemes(ref);
  }
}

String _$iconThemesHash() => r'25e3a137f1946b91fee13cc40b8f1e21ae3c8861';
