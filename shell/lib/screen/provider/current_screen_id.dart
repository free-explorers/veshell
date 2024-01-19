import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.dart';

part 'current_screen_id.g.dart';

/// Provide the current Screen to all his childrens
@Riverpod(dependencies: [])
ScreenId currentScreenId(CurrentScreenIdRef ref) {
  // This provider is instentatied in Children Scope
  throw Exception('Provider was not initialized');
}
