import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/persistence/persistable_model.mixin.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'screen.serializable.freezed.dart';
part 'screen.serializable.g.dart';

typedef ScreenId = String;

/// a Screen represent a portion of a Monitor where we want to render Veshell.
/// Monitor usually contain a single Screen but for ultra-wide monitor
/// it could be usefull to be able to split it in several Screen.
@freezed
class Screen with _$Screen implements PersistableModel {
  /// Factory
  factory Screen({
    required ScreenId screenId,
    required IList<WorkspaceId> workspaceList,
    required int selectedIndex,
    String? label,
  }) = _Screen;
  Screen._();
  factory Screen.fromJson(Map<String, dynamic> json) => _$ScreenFromJson(json);
}
