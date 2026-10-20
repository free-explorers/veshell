import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_editor_activation.g.dart';

/// The settings row whose editor should be opened next, per overview screen.
///
/// The search field keeps the keyboard while filtering, so `Enter` on the
/// selected setting is handled by the overview rather than by the row itself.
/// The overview requests the row's path here and the row consumes it to
/// expand its editor.
@riverpod
class SettingsEditorActivation extends _$SettingsEditorActivation {
  @override
  String? build(String screenId) => null;

  /// Asks the editor at [path] to open.
  // A named method reads better at the call site than a setter.
  // ignore: use_setters_to_change_properties
  void request(String path) => state = path;

  /// Clears the request once the row at [path] has handled it.
  void consume(String path) {
    if (state == path) {
      state = null;
    }
  }
}
