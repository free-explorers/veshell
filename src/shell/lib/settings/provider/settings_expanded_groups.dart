import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_expanded_groups.g.dart';

/// The settings groups currently expanded in the search result.
///
/// A single set rather than a family keyed by path, so the visible-row list can
/// be derived from it and keyboard navigation can walk the open tree.
@riverpod
class SettingsExpandedGroups extends _$SettingsExpandedGroups {
  @override
  ISet<String> build() => <String>{}.lock;

  /// Opens [path] when closed and closes it when open.
  void toggle(String path) {
    state = state.contains(path) ? state.remove(path) : state.add(path);
  }
}
