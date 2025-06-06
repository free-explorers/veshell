import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';

part 'ephemeral_window.freezed.dart';

@freezed
abstract class EphemeralWindow with _$EphemeralWindow implements Window {
  const factory EphemeralWindow({
    required EphemeralWindowId windowId,
    required WindowProperties properties,
    required ScreenId screenId,
    MetaWindowId? metaWindowId,
  }) = _EphemeralWindow;
}
