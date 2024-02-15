import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'monitor_layout_changed.serializable.freezed.dart';
part 'monitor_layout_changed.serializable.g.dart';

/// Model for MonitorLayoutChangedMessage
@freezed
class MonitorLayoutChangedMessage
    with _$MonitorLayoutChangedMessage
    implements WaylandMessage {
  /// Factory
  factory MonitorLayoutChangedMessage({
    required List<Monitor> monitors,
  }) = _MonitorLayoutChangedMessage;

  factory MonitorLayoutChangedMessage.fromJson(Map<String, dynamic> json) =>
      _$MonitorLayoutChangedMessageFromJson(json);
}
