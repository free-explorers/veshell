// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dialog_window_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Workspace provider

@ProviderFor(DialogWindowState)
const dialogWindowStateProvider = DialogWindowStateFamily._();

/// Workspace provider
final class DialogWindowStateProvider
    extends $NotifierProvider<DialogWindowState, DialogWindow> {
  /// Workspace provider
  const DialogWindowStateProvider._({
    required DialogWindowStateFamily super.from,
    required DialogWindowId super.argument,
  }) : super(
         retry: null,
         name: r'dialogWindowStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dialogWindowStateHash();

  @override
  String toString() {
    return r'dialogWindowStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DialogWindowState create() => DialogWindowState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DialogWindow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DialogWindow>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DialogWindowStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dialogWindowStateHash() => r'af20321f7706d1ed7a6b4b9316fa02d78ef5ae80';

/// Workspace provider

final class DialogWindowStateFamily extends $Family
    with
        $ClassFamilyOverride<
          DialogWindowState,
          DialogWindow,
          DialogWindow,
          DialogWindow,
          DialogWindowId
        > {
  const DialogWindowStateFamily._()
    : super(
        retry: null,
        name: r'dialogWindowStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Workspace provider

  DialogWindowStateProvider call(DialogWindowId windowId) =>
      DialogWindowStateProvider._(argument: windowId, from: this);

  @override
  String toString() => r'dialogWindowStateProvider';
}

/// Workspace provider

abstract class _$DialogWindowState extends $Notifier<DialogWindow> {
  late final _$args = ref.$arg as DialogWindowId;
  DialogWindowId get windowId => _$args;

  DialogWindow build(DialogWindowId windowId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<DialogWindow, DialogWindow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DialogWindow, DialogWindow>,
              DialogWindow,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
