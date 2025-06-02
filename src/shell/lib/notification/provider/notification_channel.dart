import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/notification/model/notification.serializable.dart';

part 'notification_channel.g.dart';

/// A Notification channel is a list of notifications for a specific name
/// It can be used to group notification for screens or specific windows
@riverpod
class NotificationChannel extends _$NotificationChannel {
  @override
  ISet<Notification> build(String channelName) {
    return <Notification>{}.lock;
  }

  void add(Notification notification) {
    state = state.add(notification);
    Timer(const Duration(seconds: 10), () {
      remove(notification.id);
    });
  }

  void remove(int id) {
    state = state.removeWhere((notification) => notification.id == id);
  }
}
