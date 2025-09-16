// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NotificationList)
const notificationListProvider = NotificationListProvider._();

final class NotificationListProvider
    extends $NotifierProvider<NotificationList, IList<Notification>> {
  const NotificationListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationListHash();

  @$internal
  @override
  NotificationList create() => NotificationList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IList<Notification> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IList<Notification>>(value),
    );
  }
}

String _$notificationListHash() => r'373b5434f7ba8cf563e9d991cc9567609b385828';

abstract class _$NotificationList extends $Notifier<IList<Notification>> {
  IList<Notification> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<IList<Notification>, IList<Notification>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<IList<Notification>, IList<Notification>>,
              IList<Notification>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
