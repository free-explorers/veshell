import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_grid.dart';

class AppDrawer extends HookConsumerWidget {
  const AppDrawer({
    required this.onSelect,
    required this.searchFocusNode,
    super.key,
  });
  final DesktopEntrySelectedCallback onSelect;

  /// The launcher tile's search node.
  ///
  /// The tile owns the keyboard policy — it focuses this node from its scope's
  /// focus event — so the field never asks for the focus itself.
  final FocusNode searchFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchTextState = useState('');
    final desktopEntries = ref.watch(
      appDrawerFilteredDesktopEntriesProvider(searchTextState.value),
    );

    // `Enter` in the search box launches the first matching application, so a
    // search can be accepted without reaching for the mouse.
    void launchFirstEntry() {
      final entries = desktopEntries.value;
      if (entries == null || entries.isEmpty) {
        return;
      }
      onSelect(entries.first);
    }

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AppDrawerTextField(
            searchFocusNode: searchFocusNode,
            onSearchTextChange: (searchText) {
              searchTextState.value = searchText;
            },
            onSubmitted: launchFirstEntry,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child: AppGrid(
                searchText: searchTextState.value,
                onSelect: onSelect,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppDrawerTextField extends HookConsumerWidget {
  const _AppDrawerTextField({
    required this.searchFocusNode,
    required this.onSearchTextChange,
    required this.onSubmitted,
  });

  final FocusNode searchFocusNode;
  final void Function(String searchText) onSearchTextChange;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final onListener = useMemoized(
      () => () {
        onSearchTextChange(searchController.text);
      },
    );

    useEffect(() {
      searchController.addListener(onListener);

      return () {
        searchController.removeListener(onListener);
      };
    }, [searchController]);

    return TextField(
      controller: searchController,
      focusNode: searchFocusNode,
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: ShellIcon(MdiIcons.magnify),
        ),
        hintText: context.l10n.searchApps,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}
