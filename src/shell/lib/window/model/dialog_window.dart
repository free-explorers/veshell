import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';

part 'dialog_window.freezed.dart';

@freezed
abstract class DialogWindow with _$DialogWindow implements Window {
  const factory DialogWindow({
    required DialogWindowId windowId,
    required WindowProperties properties,
    required MetaWindowId metaWindowId,
    required WindowId parentWindowId,
  }) = _DialogWindow;
}
