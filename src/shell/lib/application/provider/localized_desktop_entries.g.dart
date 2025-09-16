// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'localized_desktop_entries.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(localizedDesktopEntries)
const localizedDesktopEntriesProvider = LocalizedDesktopEntriesProvider._();

final class LocalizedDesktopEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, LocalizedDesktopEntry>>,
          Map<String, LocalizedDesktopEntry>,
          FutureOr<Map<String, LocalizedDesktopEntry>>
        >
    with
        $FutureModifier<Map<String, LocalizedDesktopEntry>>,
        $FutureProvider<Map<String, LocalizedDesktopEntry>> {
  const LocalizedDesktopEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localizedDesktopEntriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localizedDesktopEntriesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, LocalizedDesktopEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, LocalizedDesktopEntry>> create(Ref ref) {
    return localizedDesktopEntries(ref);
  }
}

String _$localizedDesktopEntriesHash() =>
    r'ba4962cf07ecbcc73ee6b9c47716e8306cec42cc';

@ProviderFor(LocalizedDesktopEntryForId)
const localizedDesktopEntryForIdProvider = LocalizedDesktopEntryForIdFamily._();

final class LocalizedDesktopEntryForIdProvider
    extends
        $AsyncNotifierProvider<
          LocalizedDesktopEntryForId,
          LocalizedDesktopEntry?
        > {
  const LocalizedDesktopEntryForIdProvider._({
    required LocalizedDesktopEntryForIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'localizedDesktopEntryForIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$localizedDesktopEntryForIdHash();

  @override
  String toString() {
    return r'localizedDesktopEntryForIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LocalizedDesktopEntryForId create() => LocalizedDesktopEntryForId();

  @override
  bool operator ==(Object other) {
    return other is LocalizedDesktopEntryForIdProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$localizedDesktopEntryForIdHash() =>
    r'bc949e2205604682d458268b0398efb0fe88f8c6';

final class LocalizedDesktopEntryForIdFamily extends $Family
    with
        $ClassFamilyOverride<
          LocalizedDesktopEntryForId,
          AsyncValue<LocalizedDesktopEntry?>,
          LocalizedDesktopEntry?,
          FutureOr<LocalizedDesktopEntry?>,
          String
        > {
  const LocalizedDesktopEntryForIdFamily._()
    : super(
        retry: null,
        name: r'localizedDesktopEntryForIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LocalizedDesktopEntryForIdProvider call(String appId) =>
      LocalizedDesktopEntryForIdProvider._(argument: appId, from: this);

  @override
  String toString() => r'localizedDesktopEntryForIdProvider';
}

abstract class _$LocalizedDesktopEntryForId
    extends $AsyncNotifier<LocalizedDesktopEntry?> {
  late final _$args = ref.$arg as String;
  String get appId => _$args;

  FutureOr<LocalizedDesktopEntry?> build(String appId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref
            as $Ref<AsyncValue<LocalizedDesktopEntry?>, LocalizedDesktopEntry?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<LocalizedDesktopEntry?>,
                LocalizedDesktopEntry?
              >,
              AsyncValue<LocalizedDesktopEntry?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(BinaryToAppId)
const binaryToAppIdProvider = BinaryToAppIdProvider._();

final class BinaryToAppIdProvider
    extends $AsyncNotifierProvider<BinaryToAppId, Map<String, String?>> {
  const BinaryToAppIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'binaryToAppIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$binaryToAppIdHash();

  @$internal
  @override
  BinaryToAppId create() => BinaryToAppId();
}

String _$binaryToAppIdHash() => r'2d05b44a7d6357f7012264f2cb6deb6a8ad8edd9';

abstract class _$BinaryToAppId extends $AsyncNotifier<Map<String, String?>> {
  FutureOr<Map<String, String?>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<Map<String, String?>>, Map<String, String?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<String, String?>>,
                Map<String, String?>
              >,
              AsyncValue<Map<String, String?>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
