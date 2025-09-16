// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dialog_set_for_window.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DialogSetForWindow)
const dialogSetForWindowProvider = DialogSetForWindowFamily._();

final class DialogSetForWindowProvider
    extends $NotifierProvider<DialogSetForWindow, ISet<DialogWindowId>> {
  const DialogSetForWindowProvider._({
    required DialogSetForWindowFamily super.from,
    required WindowId super.argument,
  }) : super(
         retry: null,
         name: r'dialogSetForWindowProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dialogSetForWindowHash();

  @override
  String toString() {
    return r'dialogSetForWindowProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DialogSetForWindow create() => DialogSetForWindow();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISet<DialogWindowId> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISet<DialogWindowId>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DialogSetForWindowProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dialogSetForWindowHash() =>
    r'87a6ab379460174d093e5083d887fef890d5e257';

final class DialogSetForWindowFamily extends $Family
    with
        $ClassFamilyOverride<
          DialogSetForWindow,
          ISet<DialogWindowId>,
          ISet<DialogWindowId>,
          ISet<DialogWindowId>,
          WindowId
        > {
  const DialogSetForWindowFamily._()
    : super(
        retry: null,
        name: r'dialogSetForWindowProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DialogSetForWindowProvider call(WindowId parentId) =>
      DialogSetForWindowProvider._(argument: parentId, from: this);

  @override
  String toString() => r'dialogSetForWindowProvider';
}

abstract class _$DialogSetForWindow extends $Notifier<ISet<DialogWindowId>> {
  late final _$args = ref.$arg as WindowId;
  WindowId get parentId => _$args;

  ISet<DialogWindowId> build(WindowId parentId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<ISet<DialogWindowId>, ISet<DialogWindowId>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ISet<DialogWindowId>, ISet<DialogWindowId>>,
              ISet<DialogWindowId>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
