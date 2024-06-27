import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_grid.dart';

class AppDrawer extends HookConsumerWidget {
  const AppDrawer({required this.onSelect, super.key});
  final DesktopEntrySelectedCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchTextState = useState('');
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AppDrawerTextField(
            onSearchTextChange: (searchText) {
              searchTextState.value = searchText;
            },
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
  const _AppDrawerTextField({required this.onSearchTextChange});

  final void Function(
    String searchText,
  ) onSearchTextChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final onListener = useMemoized(
      () => () {
        onSearchTextChange(searchController.text);
      },
    );
    useEffect(
      () {
        searchController.addListener(onListener);

        return () {
          searchController.removeListener(onListener);
        };
      },
      [searchController],
    );
    final scope = FocusScope.of(context);
    if (scope.hasFocus) {
      scope.autofocus(searchFocusNode);
    }

    return TextField(
      controller: searchController,
      focusNode: searchFocusNode,
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Icon(Icons.search),
        ),
        hintText: 'Search apps',
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
