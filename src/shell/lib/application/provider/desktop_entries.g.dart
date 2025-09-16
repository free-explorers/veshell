// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desktop_entries.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(installedDesktopEntries)
const installedDesktopEntriesProvider = InstalledDesktopEntriesProvider._();

final class InstalledDesktopEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, DesktopEntry>>,
          Map<String, DesktopEntry>,
          FutureOr<Map<String, DesktopEntry>>
        >
    with
        $FutureModifier<Map<String, DesktopEntry>>,
        $FutureProvider<Map<String, DesktopEntry>> {
  const InstalledDesktopEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedDesktopEntriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedDesktopEntriesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, DesktopEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, DesktopEntry>> create(Ref ref) {
    return installedDesktopEntries(ref);
  }
}

String _$installedDesktopEntriesHash() =>
    r'c66c59c6dce6c78cf2eb76661d9092ed4a1cb26e';
