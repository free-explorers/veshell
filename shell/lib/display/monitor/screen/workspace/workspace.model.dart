import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/window/window.manager.dart';

part 'workspace.model.freezed.dart';

@freezed
class Workspace with _$Workspace {
  factory Workspace({
    required IList<WindowId> tileableWindowList,
  }) = _Workspace;
}
