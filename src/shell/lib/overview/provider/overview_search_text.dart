import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'overview_search_text.g.dart';

/// Live text typed into a screen's overview search box.
///
/// It lives outside `SearchEngine` so the overview-level keyboard shortcuts can
/// read it even while the search field does not hold focus.
@riverpod
class OverviewSearchText extends _$OverviewSearchText {
  @override
  String build(ScreenId screenId) => '';

  /// Replaces the current search text.
  void setText(String text) {
    if (state == text) {
      return;
    }
    state = text;
  }
}
