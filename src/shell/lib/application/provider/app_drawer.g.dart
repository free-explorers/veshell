// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_drawer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDrawerFilteredDesktopEntries)
const appDrawerFilteredDesktopEntriesProvider =
    AppDrawerFilteredDesktopEntriesFamily._();

final class AppDrawerFilteredDesktopEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LocalizedDesktopEntry>>,
          List<LocalizedDesktopEntry>,
          FutureOr<List<LocalizedDesktopEntry>>
        >
    with
        $FutureModifier<List<LocalizedDesktopEntry>>,
        $FutureProvider<List<LocalizedDesktopEntry>> {
  const AppDrawerFilteredDesktopEntriesProvider._({
    required AppDrawerFilteredDesktopEntriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'appDrawerFilteredDesktopEntriesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$appDrawerFilteredDesktopEntriesHash();

  @override
  String toString() {
    return r'appDrawerFilteredDesktopEntriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LocalizedDesktopEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LocalizedDesktopEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return appDrawerFilteredDesktopEntries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AppDrawerFilteredDesktopEntriesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$appDrawerFilteredDesktopEntriesHash() =>
    r'9a60e08fc1edaf10f6b4dbf8f3ca709bc2122bb6';

final class AppDrawerFilteredDesktopEntriesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<LocalizedDesktopEntry>>,
          String
        > {
  const AppDrawerFilteredDesktopEntriesFamily._()
    : super(
        retry: null,
        name: r'appDrawerFilteredDesktopEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  AppDrawerFilteredDesktopEntriesProvider call(String filter) =>
      AppDrawerFilteredDesktopEntriesProvider._(argument: filter, from: this);

  @override
  String toString() => r'appDrawerFilteredDesktopEntriesProvider';
}
