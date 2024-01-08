import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.provider.dart';
import 'package:shell/manager/window/window.manager.dart';

part 'workspace.model.freezed.dart';

@freezed
class Workspace with _$Workspace {
  factory Workspace({
    required WorkspaceId workspaceId,
    required IList<WindowId> tileableWindowList,
    required int focusedIndex,
  }) = _Workspace;
}
