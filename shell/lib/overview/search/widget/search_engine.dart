import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/search/widget/application_search_result.dart';
import 'package:shell/overview/search/widget/search_input.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/theme/theme.dart';

class SearchEngine extends HookConsumerWidget {
  const SearchEngine({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final searchTextState = useState('');

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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
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
                    IconButton.filled(
                      onPressed: () {},
                      icon: const Icon(MdiIcons.playBox),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(surfaceRadius),
                        ),
                        padding: const EdgeInsets.all(12),
                        iconSize: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    IconButton(
                      onPressed: null,
                      icon: const Icon(MdiIcons.file),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(surfaceRadius),
                        ),
                        padding: const EdgeInsets.all(12),
                        iconSize: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    IconButton(
                      onPressed: null,
                      icon: const Icon(MdiIcons.cog),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(surfaceRadius),
                        ),
                        padding: const EdgeInsets.all(12),
                        iconSize: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ApplicationSearchResult(
                      searchText: searchTextState.value,
                    ),
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
