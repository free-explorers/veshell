// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'process_name.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProcessName)
const processNameProvider = ProcessNameFamily._();

final class ProcessNameProvider extends $NotifierProvider<ProcessName, String> {
  const ProcessNameProvider._({
    required ProcessNameFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'processNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$processNameHash();

  @override
  String toString() {
    return r'processNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProcessName create() => ProcessName();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProcessNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$processNameHash() => r'57548221d29e489caee463701c313a1583944290';

final class ProcessNameFamily extends $Family
    with $ClassFamilyOverride<ProcessName, String, String, String, int> {
  const ProcessNameFamily._()
    : super(
        retry: null,
        name: r'processNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProcessNameProvider call(int pid) =>
      ProcessNameProvider._(argument: pid, from: this);

  @override
  String toString() => r'processNameProvider';
}

abstract class _$ProcessName extends $Notifier<String> {
  late final _$args = ref.$arg as int;
  int get pid => _$args;

  String build(int pid);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
