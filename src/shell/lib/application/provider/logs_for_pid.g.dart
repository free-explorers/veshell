// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logs_for_pid.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LogsForPid)
const logsForPidProvider = LogsForPidFamily._();

final class LogsForPidProvider
    extends $NotifierProvider<LogsForPid, List<String>> {
  const LogsForPidProvider._({
    required LogsForPidFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'logsForPidProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$logsForPidHash();

  @override
  String toString() {
    return r'logsForPidProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LogsForPid create() => LogsForPid();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LogsForPidProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$logsForPidHash() => r'2318b02582582174b0e0cc272708a01362d2fd91';

final class LogsForPidFamily extends $Family
    with
        $ClassFamilyOverride<
          LogsForPid,
          List<String>,
          List<String>,
          List<String>,
          int
        > {
  const LogsForPidFamily._()
    : super(
        retry: null,
        name: r'logsForPidProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  LogsForPidProvider call(int pid) =>
      LogsForPidProvider._(argument: pid, from: this);

  @override
  String toString() => r'logsForPidProvider';
}

abstract class _$LogsForPid extends $Notifier<List<String>> {
  late final _$args = ref.$arg as int;
  int get pid => _$args;

  List<String> build(int pid);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
