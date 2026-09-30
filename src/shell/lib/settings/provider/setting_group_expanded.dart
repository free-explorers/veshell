import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setting_group_expanded.g.dart';

/// Whether the settings group at [path] is expanded in the search result.
///
/// Centralised so the keyboard (`Super+D`) and a click share the same state.
@riverpod
class SettingGroupExpanded extends _$SettingGroupExpanded {
  @override
  bool build(String path) => false;

  /// Opens the group when closed and closes it when open.
  void toggle() => state = !state;
}
