// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_display_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CurrentWorkspaceDisplayMode)
const currentWorkspaceDisplayModeProvider =
    CurrentWorkspaceDisplayModeProvider._();

final class CurrentWorkspaceDisplayModeProvider
    extends
        $FunctionalProvider<
          WorkspaceDisplayMode,
          WorkspaceDisplayMode,
          WorkspaceDisplayMode
        >
    with $Provider<WorkspaceDisplayMode> {
  const CurrentWorkspaceDisplayModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentWorkspaceDisplayModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentWorkspaceDisplayModeHash();

  @$internal
  @override
  $ProviderElement<WorkspaceDisplayMode> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceDisplayMode create(Ref ref) {
    return CurrentWorkspaceDisplayMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceDisplayMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceDisplayMode>(value),
    );
  }
}

String _$currentWorkspaceDisplayModeHash() =>
    r'64c79a9b15fa91b2c7fc225a9a6cfbcdcb9eae45';
