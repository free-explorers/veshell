// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_drawer_desktop_entries.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDrawerDesktopEntries)
const appDrawerDesktopEntriesProvider = AppDrawerDesktopEntriesProvider._();

final class AppDrawerDesktopEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Iterable<LocalizedDesktopEntry>>,
          Iterable<LocalizedDesktopEntry>,
          FutureOr<Iterable<LocalizedDesktopEntry>>
        >
    with
        $FutureModifier<Iterable<LocalizedDesktopEntry>>,
        $FutureProvider<Iterable<LocalizedDesktopEntry>> {
  const AppDrawerDesktopEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDrawerDesktopEntriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDrawerDesktopEntriesHash();

  @$internal
  @override
  $FutureProviderElement<Iterable<LocalizedDesktopEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Iterable<LocalizedDesktopEntry>> create(Ref ref) {
    return appDrawerDesktopEntries(ref);
  }
}

String _$appDrawerDesktopEntriesHash() =>
    r'b6dd74d1d98df2497bda124ec44c4e9cf5d2bc25';
