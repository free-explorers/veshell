import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/window/model/window_properties.serializable.dart';

part 'matching_info.serializable.freezed.dart';
part 'matching_info.serializable.g.dart';

@freezed
abstract class MatchingInfo with _$MatchingInfo {
  const factory MatchingInfo({
    required String appId,
    String? title,
    String? windowClass,
    String? startupId,
    int? pid,
    DateTime? matchedAtTime,
    DateTime? waitingForAppSince,
    bool? matchedWhileWaiting,
  }) = _MatchingInfo;

  factory MatchingInfo.fromWindowProperties(WindowProperties props) =>
      MatchingInfo(
        appId: props.appId,
        title: props.title,
        windowClass: props.windowClass,
        startupId: props.startupId,
        pid: props.pid,
      );

  factory MatchingInfo.fromJson(Map<String, dynamic> json) =>
      _$MatchingInfoFromJson(json);
}
