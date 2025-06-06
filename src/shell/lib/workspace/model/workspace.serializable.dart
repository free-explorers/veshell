import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'workspace.serializable.freezed.dart';
part 'workspace.serializable.g.dart';

@freezed
abstract class Workspace with _$Workspace {
  factory Workspace({
    required WorkspaceId workspaceId,
    required IList<PersistentWindowId> tileableWindowList,
    required int selectedIndex,
    required int visibleLength,
    WorkspaceCategory? category,
    WorkspaceCategory? forcedCategory,
  }) = _Workspace;
  Workspace._();

  factory Workspace.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceFromJson(json);
}
