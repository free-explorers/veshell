import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.dart';

part 'focused_screen.g.dart';

/// Provide the current Focused screen
@riverpod
ScreenId? focusedScreen(FocusedScreenRef ref) {
  return null;

  //return ref.watch(screenListProvider).first;
}
