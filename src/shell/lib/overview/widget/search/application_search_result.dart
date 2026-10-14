import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/overview/widget/overview_shortcuts.dart';
import 'package:shell/shared/widget/focus_highlight.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';

/// Height of one application row; fixed so the selection can be scrolled into
/// view by index.
const applicationRowHeight = 72.0;

/// List of applications for the given searchText, navigable by selection index.
///
/// Each row owns a focus node ([OverviewResultFocus.rowNode]) and the selection
/// index is a roving cursor over them: moving the cursor moves the keyboard
/// focus onto the row, so assistive technology follows the selection, the
/// highlight stays in step, and activation (`ActivateIntent`, i.e. `Enter`)
/// acts on the selected row.
class ApplicationSearchResult extends HookConsumerWidget {
  ///
  const ApplicationSearchResult({
    required this.searchText,
    this.selectedIndex,
    this.onSelect,
    this.onActivate,
    this.resultFocus,
    super.key,
  });
  final String searchText;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;
  final ValueChanged<int>? onActivate;
  final OverviewResultFocus? resultFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktopEntries = ref.watch(
      appDrawerFilteredDesktopEntriesProvider(searchText),
    );
    final scrollController = useScrollController();

    // A single click selects, focuses the row and launches the application.
    void handleTap(int index) {
      resultFocus?.moveTo(index);
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
      data: (entryList) {
        final focus = resultFocus;
        final list = ListView.builder(
          controller: scrollController,
          itemExtent: applicationRowHeight,
          itemCount: entryList.length,
          itemBuilder: (context, index) {
            final entry = entryList[index];
            return _ApplicationRow(
              entry: entry,
              isSelected: index == selectedIndex,
              focusNode: focus?.rowNode(index),
              onFocus: (focus == null || onSelect == null)
                  ? null
                  : () => onSelect!(index),
              onTap: (onSelect == null && onActivate == null)
                  ? null
                  : () => handleTap(index),
            );
          },
        );

        if (focus == null) {
          return list;
        }

        return Actions(
          actions: {
            NavigateIntent: CallbackAction<NavigateIntent>(
              onInvoke: (intent) {
                switch (intent.direction) {
                  case NavigationDirection.up:
                    final index = selectedIndex;
                    if (index == null || index <= 0) {
                      focus.focusSearch();
                    } else {
                      onSelect?.call(index - 1);
                      focus.moveTo(index - 1);
                    }
                  case NavigationDirection.down:
                    final index = selectedIndex;
                    final next = index == null ? 0 : index + 1;
                    if (next < entryList.length) {
                      onSelect?.call(next);
                      focus.moveTo(next);
                    }
                  case NavigationDirection.left:
                  case NavigationDirection.right:
                    primaryFocus?.focusInDirection(
                      intent.direction == NavigationDirection.left
                          ? TraversalDirection.left
                          : TraversalDirection.right,
                    );
                }
                return null;
              },
            ),
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onActivate?.call(selectedIndex ?? 0);
                return null;
              },
            ),
          },
          child: list,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({
    required this.entry,
    required this.isSelected,
    this.focusNode,
    this.onFocus,
    this.onTap,
  });

  final LocalizedDesktopEntry entry;
  final bool isSelected;
  final FocusNode? focusNode;
  final VoidCallback? onFocus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FocusHighlight(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        }
      },
      // The fill follows the focus, so navigating the keyboard out of the list
      // clears the last row instead of leaving it painted. Rows without a focus
      // node (no roving list) keep the selection fill.
      builder: (context, hasFocus) => _buildRow(
        context,
        highlighted: focusNode == null ? isSelected : hasFocus,
      ),
    );
  }

  Widget _buildRow(BuildContext context, {required bool highlighted}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: highlighted ? colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // The row's `Focus` node owns keyboard focus; the ink response only
        // provides the pointer affordance and its action.
        canRequestFocus: false,
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
