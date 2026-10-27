import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

part 'focus_indicator_setting.g.dart';

/// How the focused tile stands out when several tiles share the workspace.
///
/// The enum names are the values stored under `theme.focusIndicator`.
enum FocusIndicator {
  /// A primary-colored bar above and below the focused tile, sliding from
  /// tile to tile as the focus moves.
  border,

  /// Unfocused tiles are shown in grayscale.
  grayscale,

  /// No extra emphasis beyond the workspace panel.
  none,
}

const focusIndicatorPath = 'theme.focusIndicator';
const FocusIndicator focusIndicatorFallback = FocusIndicator.border;

@riverpod
FocusIndicator focusIndicatorSetting(Ref ref) {
  final value = ref.watch(jsonValueByPathProvider(focusIndicatorPath));
  return FocusIndicator.values.asNameMap()[value] ?? focusIndicatorFallback;
}
