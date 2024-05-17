import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'overview_is_displayed.g.dart';

@riverpod
class OverviewIsDisplayed extends _$OverviewIsDisplayed {
  @override
  bool build(ScreenId screenId) {
    return false;
  }

  toggle() {
    state = !state;
  }
}
