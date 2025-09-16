// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_channel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A Notification channel is a list of notifications for a specific name
/// It can be used to group notification for screens or specific windows

@ProviderFor(NotificationChannel)
const notificationChannelProvider = NotificationChannelFamily._();

/// A Notification channel is a list of notifications for a specific name
/// It can be used to group notification for screens or specific windows
final class NotificationChannelProvider
    extends $NotifierProvider<NotificationChannel, ISet<Notification>> {
  /// A Notification channel is a list of notifications for a specific name
  /// It can be used to group notification for screens or specific windows
  const NotificationChannelProvider._({
    required NotificationChannelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'notificationChannelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$notificationChannelHash();

  @override
  String toString() {
    return r'notificationChannelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  NotificationChannel create() => NotificationChannel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISet<Notification> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISet<Notification>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationChannelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$notificationChannelHash() =>
    r'1d49e2732ddc187312d9c5e237bf6d4c902581f8';

/// A Notification channel is a list of notifications for a specific name
/// It can be used to group notification for screens or specific windows

final class NotificationChannelFamily extends $Family
    with
        $ClassFamilyOverride<
          NotificationChannel,
          ISet<Notification>,
          ISet<Notification>,
          ISet<Notification>,
          String
        > {
  const NotificationChannelFamily._()
    : super(
        retry: null,
        name: r'notificationChannelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A Notification channel is a list of notifications for a specific name
  /// It can be used to group notification for screens or specific windows

  NotificationChannelProvider call(String channelName) =>
      NotificationChannelProvider._(argument: channelName, from: this);

  @override
  String toString() => r'notificationChannelProvider';
}

/// A Notification channel is a list of notifications for a specific name
/// It can be used to group notification for screens or specific windows

abstract class _$NotificationChannel extends $Notifier<ISet<Notification>> {
  late final _$args = ref.$arg as String;
  String get channelName => _$args;

  ISet<Notification> build(String channelName);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<ISet<Notification>, ISet<Notification>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ISet<Notification>, ISet<Notification>>,
              ISet<Notification>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
