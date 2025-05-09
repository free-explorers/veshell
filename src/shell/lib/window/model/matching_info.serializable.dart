import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
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
    DateTime? waitingForAppSince,
  }) = _MatchingInfo;

  factory MatchingInfo.fromWindowProperties(WindowProperties props) =>
      MatchingInfo(
        appId: props.appId,
        title: props.title,
        windowClass: props.windowClass,
        startupId: props.startupId,
        pid: props.pid,
      );

  factory MatchingInfo.fromMetaWindow(MetaWindow metaWindow) => MatchingInfo(
        appId: metaWindow.appId ?? '',
        title: metaWindow.title,
        windowClass: metaWindow.windowClass,
        startupId: metaWindow.startupId,
        pid: metaWindow.pid,
      );

  factory MatchingInfo.fromJson(Map<String, dynamic> json) =>
      _$MatchingInfoFromJson(json);
}
