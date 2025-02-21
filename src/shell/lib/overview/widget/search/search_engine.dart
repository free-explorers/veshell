import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/widget/search/application_search_result.dart';
import 'package:shell/overview/widget/search/file_search_result.dart';
import 'package:shell/overview/widget/search/search_input.dart';
import 'package:shell/overview/widget/search/settings/settings_search_result.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/theme/provider/theme.dart';

enum SearchMode { application, file, settings }

class SearchEngine extends HookConsumerWidget {
  const SearchEngine({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final searchTextState = useState('');
    final searchMode = useState(SearchMode.application);
    useEffect(
      () {
        searchController.addListener(() {
          searchTextState.value = searchController.text;
        });
        searchFocusNode.requestFocus();
        focusLog.info('Search request at first build');
        return null;
      },
      [],
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        color: Theme.of(context).colorScheme.surface.withAlpha(200),
      ),
      child: Column(
        children: [
          SearchInput(
            searchController: searchController,
            searchFocusNode: searchFocusNode,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    SearchModeButton(
                      icon: const Icon(MdiIcons.playBox),
                      onSelected: () {
                        searchMode.value = SearchMode.application;
                      },
                      isSelected: searchMode.value == SearchMode.application,
                    ),
                    const SizedBox(height: 16),
                    SearchModeButton(
                      icon: const Icon(MdiIcons.file),
                      onSelected: () {
                        searchMode.value = SearchMode.file;
                      },
                      isSelected: searchMode.value == SearchMode.file,
                    ),
                    const SizedBox(height: 16),
                    SearchModeButton(
                      icon: const Icon(MdiIcons.cog),
                      onSelected: () {
                        searchMode.value = SearchMode.settings;
                      },
                      isSelected: searchMode.value == SearchMode.settings,
                    ),
                  ],
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: switch (searchMode.value) {
                      SearchMode.application => ApplicationSearchResult(
                          searchText: searchTextState.value,
                        ),
                      SearchMode.file => FileSearchResult(
                          searchText: searchTextState.value,
                        ),
                      SearchMode.settings => SettingsSearchResult(
                          searchText: searchTextState.value,
                        ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SearchModeButton extends StatelessWidget {
  const SearchModeButton({
    required this.icon,
    required this.onSelected,
    this.isSelected = false,
    super.key,
  });

  final bool isSelected;
  final Widget icon;
  final void Function()? onSelected;
  @override
  Widget build(BuildContext context) {
    var buttonType = IconButton.new;
    var style = IconButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(surfaceRadius),
      ),
      padding: const EdgeInsets.all(12),
      iconSize: 28,
    );
    if (isSelected) {
      buttonType = IconButton.filled;
      style = style.copyWith(
        backgroundColor:
            WidgetStateProperty.all(Theme.of(context).colorScheme.primary),
        foregroundColor:
            WidgetStateProperty.all(Theme.of(context).colorScheme.onPrimary),
      );
    }
    return buttonType(
      onPressed: onSelected,
      icon: icon,
      style: style,
    );
  }
}
