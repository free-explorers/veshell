import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/settings/model/keyboard_layout.dart';
import 'package:shell/settings/model/keyboard_option.dart';

part 'keyboard_layout.g.dart';

/// The keyboard layouts and variants the compositor can compile, read from
/// libxkbregistry through the `get_keyboard_layouts` platform request.
///
/// Backs the keyboard-layout picker: the compositor answers with the same
/// catalogue its `XkbConfig` compiles, so the picker cannot offer something the
/// seat would then reject.
@riverpod
Future<List<KeyboardLayoutOption>> availableKeyboardLayouts(Ref ref) async {
  final layouts = await ref
      .watch(platformManagerProvider.notifier)
      .fetchKeyboardLayouts();
  return layouts.map(KeyboardLayoutOption.fromJson).toList(growable: false);
}

/// The xkb option groups the compositor can compile, read from libxkbregistry
/// through the `get_keyboard_options` platform request. Backs the keyboard
/// options picker.
@riverpod
Future<List<KeyboardOptionGroup>> availableKeyboardOptions(Ref ref) async {
  final groups = await ref
      .watch(platformManagerProvider.notifier)
      .fetchKeyboardOptions();
  return groups.map(KeyboardOptionGroup.fromJson).toList(growable: false);
}
