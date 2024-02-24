import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/screen/model/screen.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'workspace_drag_data.freezed.dart';

@freezed
class WorkspaceDragData with _$WorkspaceDragData {
  /// Factory
  const factory WorkspaceDragData({
    required WorkspaceId workspaceId,
    required ScreenId screenId,
  }) = _WorkspaceDragData;
}
