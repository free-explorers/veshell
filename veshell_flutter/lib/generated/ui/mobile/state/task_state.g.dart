// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/mobile/state/task_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskWidgetHash() => r'2c63f8a29f92f19882e5f0e4b1bbdde76b60398c';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

typedef TaskWidgetRef = ProviderRef<Task>;

/// See also [taskWidget].
@ProviderFor(taskWidget)
const taskWidgetProvider = TaskWidgetFamily();

/// See also [taskWidget].
class TaskWidgetFamily extends Family<Task> {
  /// See also [taskWidget].
  const TaskWidgetFamily();

  /// See also [taskWidget].
  TaskWidgetProvider call(
    int viewId,
  ) {
    return TaskWidgetProvider(
      viewId,
    );
  }

  @override
  TaskWidgetProvider getProviderOverride(
    covariant TaskWidgetProvider provider,
  ) {
    return call(
      provider.viewId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'taskWidgetProvider';
}

/// See also [taskWidget].
class TaskWidgetProvider extends Provider<Task> {
  /// See also [taskWidget].
  TaskWidgetProvider(
    this.viewId,
  ) : super.internal(
          (ref) => taskWidget(
            ref,
            viewId,
          ),
          from: taskWidgetProvider,
          name: r'taskWidgetProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskWidgetHash,
          dependencies: TaskWidgetFamily._dependencies,
          allTransitiveDependencies:
              TaskWidgetFamily._allTransitiveDependencies,
        );

  final int viewId;

  @override
  bool operator ==(Object other) {
    return other is TaskWidgetProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

String _$taskStateNotifierHash() => r'e471d5b2f87ec17f9d4ea2786d580abc3cf1b0c2';

abstract class _$TaskStateNotifier extends BuildlessNotifier<TaskState> {
  late final int viewId;

  TaskState build(
    int viewId,
  );
}

/// See also [TaskStateNotifier].
@ProviderFor(TaskStateNotifier)
const taskStateNotifierProvider = TaskStateNotifierFamily();

/// See also [TaskStateNotifier].
class TaskStateNotifierFamily extends Family<TaskState> {
  /// See also [TaskStateNotifier].
  const TaskStateNotifierFamily();

  /// See also [TaskStateNotifier].
  TaskStateNotifierProvider call(
    int viewId,
  ) {
    return TaskStateNotifierProvider(
      viewId,
    );
  }

  @override
  TaskStateNotifierProvider getProviderOverride(
    covariant TaskStateNotifierProvider provider,
  ) {
    return call(
      provider.viewId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'taskStateNotifierProvider';
}

/// See also [TaskStateNotifier].
class TaskStateNotifierProvider
    extends NotifierProviderImpl<TaskStateNotifier, TaskState> {
  /// See also [TaskStateNotifier].
  TaskStateNotifierProvider(
    this.viewId,
  ) : super.internal(
          () => TaskStateNotifier()..viewId = viewId,
          from: taskStateNotifierProvider,
          name: r'taskStateNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskStateNotifierHash,
          dependencies: TaskStateNotifierFamily._dependencies,
          allTransitiveDependencies:
              TaskStateNotifierFamily._allTransitiveDependencies,
        );

  final int viewId;

  @override
  bool operator ==(Object other) {
    return other is TaskStateNotifierProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }

  @override
  TaskState runNotifierBuild(
    covariant TaskStateNotifier notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }
}

String _$taskPositionHash() => r'8b1381e2330cded890010168c7cfb8846211ce09';

abstract class _$TaskPosition extends BuildlessNotifier<double> {
  late final int viewId;

  double build(
    int viewId,
  );
}

/// See also [TaskPosition].
@ProviderFor(TaskPosition)
const taskPositionProvider = TaskPositionFamily();

/// See also [TaskPosition].
class TaskPositionFamily extends Family<double> {
  /// See also [TaskPosition].
  const TaskPositionFamily();

  /// See also [TaskPosition].
  TaskPositionProvider call(
    int viewId,
  ) {
    return TaskPositionProvider(
      viewId,
    );
  }

  @override
  TaskPositionProvider getProviderOverride(
    covariant TaskPositionProvider provider,
  ) {
    return call(
      provider.viewId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'taskPositionProvider';
}

/// See also [TaskPosition].
class TaskPositionProvider extends NotifierProviderImpl<TaskPosition, double> {
  /// See also [TaskPosition].
  TaskPositionProvider(
    this.viewId,
  ) : super.internal(
          () => TaskPosition()..viewId = viewId,
          from: taskPositionProvider,
          name: r'taskPositionProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskPositionHash,
          dependencies: TaskPositionFamily._dependencies,
          allTransitiveDependencies:
              TaskPositionFamily._allTransitiveDependencies,
        );

  final int viewId;

  @override
  bool operator ==(Object other) {
    return other is TaskPositionProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }

  @override
  double runNotifierBuild(
    covariant TaskPosition notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }
}

String _$taskVerticalPositionHash() =>
    r'39d4ef570dc6054ffe942219977cc252bc1c7627';

abstract class _$TaskVerticalPosition extends BuildlessNotifier<double> {
  late final int viewId;

  double build(
    int viewId,
  );
}

/// See also [TaskVerticalPosition].
@ProviderFor(TaskVerticalPosition)
const taskVerticalPositionProvider = TaskVerticalPositionFamily();

/// See also [TaskVerticalPosition].
class TaskVerticalPositionFamily extends Family<double> {
  /// See also [TaskVerticalPosition].
  const TaskVerticalPositionFamily();

  /// See also [TaskVerticalPosition].
  TaskVerticalPositionProvider call(
    int viewId,
  ) {
    return TaskVerticalPositionProvider(
      viewId,
    );
  }

  @override
  TaskVerticalPositionProvider getProviderOverride(
    covariant TaskVerticalPositionProvider provider,
  ) {
    return call(
      provider.viewId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'taskVerticalPositionProvider';
}

/// See also [TaskVerticalPosition].
class TaskVerticalPositionProvider
    extends NotifierProviderImpl<TaskVerticalPosition, double> {
  /// See also [TaskVerticalPosition].
  TaskVerticalPositionProvider(
    this.viewId,
  ) : super.internal(
          () => TaskVerticalPosition()..viewId = viewId,
          from: taskVerticalPositionProvider,
          name: r'taskVerticalPositionProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskVerticalPositionHash,
          dependencies: TaskVerticalPositionFamily._dependencies,
          allTransitiveDependencies:
              TaskVerticalPositionFamily._allTransitiveDependencies,
        );

  final int viewId;

  @override
  bool operator ==(Object other) {
    return other is TaskVerticalPositionProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }

  @override
  double runNotifierBuild(
    covariant TaskVerticalPosition notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }
}
// ignore_for_file: unnecessary_raw_strings, subtype_of_sealed_class, invalid_use_of_internal_member, do_not_use_environment, prefer_const_constructors, public_member_api_docs, avoid_private_typedef_functions
