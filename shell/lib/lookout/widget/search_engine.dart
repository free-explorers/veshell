import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/application/widget/app_icon.dart';

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
        return null;
      },
      [],
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            autofocus: true,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 48, 12),
                child: Icon(
                  Icons.search,
                  size: 28,
                ),
              ),
              contentPadding: const EdgeInsets.all(24),
              hintText: 'Search',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    IconButton.filled(
                      onPressed: () {},
                      icon: Icon(MdiIcons.playBox),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(12),
                        iconSize: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(MdiIcons.file),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(12),
                        iconSize: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(MdiIcons.cog),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
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
                    child: ApplicationList(
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

class ApplicationList extends HookConsumerWidget {
  const ApplicationList({required this.searchText, super.key});
  final String searchText;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktopEntries =
        ref.watch(appDrawerFilteredDesktopEntriesProvider(searchText));
    return ListView.builder(
      itemBuilder: (context, index) {
        final desktopEntry = desktopEntries.requireValue[index];
        return ListTile(
          title: Text(desktopEntry.entries[DesktopEntryKey.name.string] ?? ''),
          subtitle: Text(
            desktopEntry.entries[DesktopEntryKey.comment.string] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: SizedBox(
            width: 42,
            child: AspectRatio(
              aspectRatio: 1,
              child: AppIconByPath(
                path: desktopEntry.entries[DesktopEntryKey.icon.string],
              ),
            ),
          ),
          onTap: () {
            print(
              'Launch ${desktopEntry.entries[DesktopEntryKey.name.string]}',
            );
          },
          visualDensity: VisualDensity.comfortable,
          focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        );
      },
      itemCount: desktopEntries.maybeWhen(
        data: (desktopEntries) => desktopEntries.length,
        orElse: () => 0,
      ),
    );
  }
}
