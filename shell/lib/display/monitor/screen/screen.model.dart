import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.provider.dart';

part 'screen.model.freezed.dart';

typedef ScreenId = String;

/// a Screen represent a portion of a Monitor where we want to render Veshell.
/// Monitor usually contain a single Screen but for ultra-wide monitor
/// it could be usefull to be able to split it in several Screen.
@freezed
class Screen with _$Screen {
  /// Factory
  const factory Screen({
    required ScreenId screenId,
    required IList<WorkspaceId> workspaceList,
    required int selectedIndex,
  }) = _Screen;
}
