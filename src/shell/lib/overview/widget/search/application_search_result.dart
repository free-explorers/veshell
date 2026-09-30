import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/application/widget/app_icon.dart';

/// Height of one application row; fixed so the selection can be scrolled into
/// view by index.
const applicationRowHeight = 72.0;

/// List of applications for the given searchText, navigable by selection index.
class ApplicationSearchResult extends HookConsumerWidget {
  ///
  const ApplicationSearchResult({
    required this.searchText,
    this.selectedIndex,
    this.onSelect,
    this.onActivate,
    super.key,
  });
  final String searchText;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;
  final ValueChanged<int>? onActivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktopEntries = ref.watch(
      appDrawerFilteredDesktopEntriesProvider(searchText),
    );
    final scrollController = useScrollController();

    // A single click selects and launches the application right away.
    void handleTap(int index) {
      onSelect?.call(index);
      onActivate?.call(index);
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final index = selectedIndex;
        if (!scrollController.hasClients || index == null || index < 0) {
          return;
        }
        final position = scrollController.position;
        final itemStart = index * applicationRowHeight;
        final itemEnd = itemStart + applicationRowHeight;
        if (itemStart < position.pixels) {
          scrollController.jumpTo(itemStart);
        } else if (itemEnd > position.pixels + position.viewportDimension) {
          scrollController.jumpTo(itemEnd - position.viewportDimension);
        }
      });
      return null;
    }, [selectedIndex]);

    return desktopEntries.when(
      data: (entryList) => ListView.builder(
        controller: scrollController,
        itemExtent: applicationRowHeight,
        itemCount: entryList.length,
        itemBuilder: (context, index) {
          final entry = entryList[index];
          return _ApplicationRow(
            entry: entry,
            isSelected: index == selectedIndex,
            onTap: (onSelect == null && onActivate == null)
                ? null
                : () => handleTap(index),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({
    required this.entry,
    required this.isSelected,
    this.onTap,
  });

  final LocalizedDesktopEntry entry;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const SizedBox(width: 4),
              SizedBox(
                width: 42,
                height: 42,
                child: AppIconByPath(
                  path: entry.entries[DesktopEntryKey.icon.string],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.entries[DesktopEntryKey.name.string] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      entry.entries[DesktopEntryKey.comment.string] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
