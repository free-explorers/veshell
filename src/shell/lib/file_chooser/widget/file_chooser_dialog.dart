import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shell/file_chooser/model/file_chooser_request/file_chooser_request.serializable.dart';
import 'package:shell/file_chooser/provider/file_chooser_request.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/file_explorer/widget/file_explorer_view.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/window/model/window_id.serializable.dart';

/// Riverpod key the portal chooser uses for the (otherwise overview-owned)
/// file explorer providers: its own key keeps the chooser's browsing state
/// independent from the overview's Files pane.
const _fileChooserScreenId = '__file_chooser__';

/// The trusted FileChooser dialog.
///
/// It reuses the shell's file explorer to browse the filesystem and answers
/// the portal request with the chosen `file://` URI(s). Browse state is
/// local to the chooser: the overview's Files pane is untouched.
class FileChooserDialog extends HookConsumerWidget {
  /// constructor
  const FileChooserDialog({required this.request, super.key});

  /// The request being answered.
  final FileChooserRequestMessage request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const screenId = _fileChooserScreenId;
    final theme = Theme.of(context);
    final explorer = ref.watch(fileExplorerStateProvider(screenId));
    final entryListAsync = ref.watch(filteredEntryListProvider(screenId));
    final entryList = entryListAsync.value ?? const <FileEntry>[];

    final selectedIndex = useState<int?>(null);
    final nameText = useState(_initialName(request));
    final searchText = useState('');
    final selectedFilter = useState<int?>(null);
    final nameController = useTextEditingController(text: nameText.value);
    final searchController = useTextEditingController();

    // Seed the browser once per request: land on the requested folder (or
    // its fallback) without a surprise selection, and prefill the save name.
    useEffect(() {
      final notifier = ref.read(fileExplorerStateProvider(screenId).notifier);
      selectedIndex.value = null;
      nameText.value = _initialName(request);
      nameController.text = nameText.value;
      searchText.value = '';
      searchController.clear();
      selectedFilter.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.setInitialLocation(
          DirectoryPath(_initialDirectory(request)),
          selected: _initialSelection(request),
        );
      });
      return null;
    }, [request.consentToken]);

    // A stale index never highlights a row after the directory changes.
    useEffect(() {
      selectedIndex.value = null;
      return null;
    }, [explorer.path]);

    final selectedEntry =
        selectedIndex.value != null && selectedIndex.value! < entryList.length
        ? entryList[selectedIndex.value!]
        : null;

    final notifier = ref.read(fileExplorerStateProvider(screenId).notifier);
    final chooser = ref.read(fileChooserRequestProvider.notifier);

    void activate(int index) {
      if (index < 0 || index >= entryList.length) {
        return;
      }
      final entry = entryList[index];
      if (entry.isDirectory) {
        selectedIndex.value = null;
        // Enter the folder without auto-selecting its first entry: the
        // chooser's save name must not change just from navigating.
        notifier.setInitialLocation(entry.path);
        return;
      }
      if (request.mode == FileChooserMode.save) {
        selectedIndex.value = index;
        nameText.value = entry.name;
        nameController.text = entry.name;
        return;
      }
      chooser.approve([_fileUri(entry.path.path)]);
    }

    void select(int index) {
      selectedIndex.value = index;
      if (request.mode == FileChooserMode.save &&
          index < entryList.length &&
          !entryList[index].isDirectory) {
        nameText.value = entryList[index].name;
        nameController.text = entryList[index].name;
      }
    }

    void accept() {
      switch (request.mode) {
        case FileChooserMode.open:
          if (request.directory) {
            chooser.approve([_fileUri(explorer.path.path)]);
          } else if (selectedEntry != null && !selectedEntry.isDirectory) {
            chooser.approve([_fileUri(selectedEntry.path.path)]);
          }
        case FileChooserMode.save:
          final name = nameText.value.trim();
          if (name.isEmpty) {
            return;
          }
          chooser.approve([_fileUri(p.join(explorer.path.path, name))]);
        case FileChooserMode.saveFiles:
          if (request.files.isEmpty) {
            return;
          }
          chooser.approve([
            for (final name in request.files)
              _fileUri(p.join(explorer.path.path, name)),
          ]);
      }
    }

    final acceptEnabled = switch (request.mode) {
      FileChooserMode.open =>
        request.directory ||
            (selectedEntry != null && !selectedEntry.isDirectory),
      FileChooserMode.save => nameText.value.trim().isNotEmpty,
      FileChooserMode.saveFiles => request.files.isNotEmpty,
    };
    final acceptLabel = switch (request.acceptLabel) {
      final label? when label.isNotEmpty => label,
      _ =>
        request.mode == FileChooserMode.open
            ? context.l10n.open
            : context.l10n.save,
    };
    final title = request.title.isNotEmpty
        ? request.title
        : switch (request.mode) {
            FileChooserMode.open => context.l10n.openFile,
            FileChooserMode.save => context.l10n.saveFile,
            FileChooserMode.saveFiles => context.l10n.saveFiles,
          };

    return Card(
      color: theme.colorScheme.surfaceContainer,
      child: CurrentScreenId(
        screenId: screenId,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): chooser.cancel,
          },
          child: Focus(
            autofocus: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleLarge),
                            if (request.appName.isNotEmpty)
                              Text(
                                request.appName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.close,
                        onPressed: chooser.cancel,
                        icon: const ShellIcon(MdiIcons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (request.mode == FileChooserMode.open) ...[
                    if (request.filters.isNotEmpty) ...[
                      DropdownButtonFormField<int?>(
                        initialValue: selectedFilter.value,
                        decoration: InputDecoration(
                          labelText: context.l10n.fileType,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            child: Text(context.l10n.allFiles),
                          ),
                          for (var i = 0; i < request.filters.length; i++)
                            DropdownMenuItem<int?>(
                              value: i,
                              child: Text(request.filters[i].name),
                            ),
                        ],
                        onChanged: (index) {
                          selectedFilter.value = index;
                          final query = index == null
                              ? ''
                              : _searchForFilter(request.filters[index]);
                          searchText.value = query;
                          searchController.text = query;
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: searchController,
                      onChanged: (value) => searchText.value = value,
                      decoration: InputDecoration(
                        labelText: context.l10n.search,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (request.mode == FileChooserMode.saveFiles &&
                      request.files.isNotEmpty) ...[
                    Text(
                      request.files.join(', '),
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: FileExplorerView(
                      searchText: searchText.value,
                      selectedIndex: selectedIndex.value,
                      onSelect: select,
                      onActivate: activate,
                      onOpenDirectory: notifier.openBreadcrumb,
                      onOpenParent: notifier.openParentDirectory,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (request.mode == FileChooserMode.save) ...[
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            autofocus: true,
                            onChanged: (value) => nameText.value = value,
                            decoration: InputDecoration(
                              labelText: context.l10n.fileName,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else
                        const Spacer(),
                      FilledButton(
                        onPressed: acceptEnabled ? accept : null,
                        child: Text(acceptLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chooser drawn as a modal over its host: a scrim plus the dialog card.
///
/// Used both inside the owning window container (the requester's tile) and as
/// the monitor overlay fallback when the request has no window container.
class FileChooserModal extends StatelessWidget {
  /// constructor
  const FileChooserModal({required this.request, super.key});

  /// The request being answered.
  final FileChooserRequestMessage request;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black38),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            // The monitor fallback floats free, so it keeps a bounded size;
            // inside a window container the dialog fills its area instead.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
              // Keying by consent token resets the browse state when a new
              // request replaces the current one.
              child: FileChooserDialog(
                key: ValueKey(request.consentToken),
                request: request,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mounts the file chooser into the shell tree.
///
/// A request whose requester resolves to a window container is rendered there
/// (inside the tile, like a native dialog); this host only draws the monitor
/// overlay fallback for a request with no container — an unknown requester, or
/// an owner kind that renders no chooser.
class FileChooserHost extends ConsumerWidget {
  /// constructor
  const FileChooserHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(fileChooserRequestProvider);
    if (request == null) {
      return const SizedBox.shrink();
    }
    final metaWindowId = request.metaWindowId;
    final owner = metaWindowId == null
        ? null
        : ref.watch(metaWindowWindowMapProvider)[metaWindowId];
    if (owner is PersistentWindowId || owner is EphemeralWindowId) {
      return const SizedBox.shrink();
    }
    // The monitor fallback sits beside the Navigator, so it lacks the
    // Navigator's `Overlay`: the text fields, the filter dropdown and the
    // tooltips need one.
    return Overlay.wrap(child: FileChooserModal(request: request));
  }
}

/// The `file://` URI the portal result carries.
String _fileUri(String path) => Uri.file(path).toString();

/// The user's home directory, or the filesystem root when `HOME` is unset.
String _homeDirectory() {
  final home = Platform.environment['HOME'];
  return home != null && home.isNotEmpty ? home : '/';
}

/// The folder the chooser opens on: the suggested file's folder, then the
/// suggested folder, then `$HOME`.
String _initialDirectory(FileChooserRequestMessage request) {
  final file = request.currentFile;
  if (file != null && file.isNotEmpty) {
    return p.dirname(file);
  }
  final folder = request.currentFolder;
  if (folder != null && folder.isNotEmpty) {
    return folder;
  }
  return _homeDirectory();
}

/// The entry pre-selected once the initial listing loads (an open request
/// naming an existing file), or `null`.
DirectoryPath? _initialSelection(FileChooserRequestMessage request) {
  final file = request.currentFile;
  if (request.mode == FileChooserMode.open && file != null && file.isNotEmpty) {
    return DirectoryPath(file);
  }
  return null;
}

/// The suggested save name: `current_name`, then the suggested file's name.
String _initialName(FileChooserRequestMessage request) {
  final name = request.currentName;
  if (name != null && name.isNotEmpty) {
    return name;
  }
  final file = request.currentFile;
  if (file != null && file.isNotEmpty) {
    return p.basename(file);
  }
  return '';
}

/// A live-list filter derived from a filter's first glob pattern (`*.png`
/// becomes the `.png` substring the explorer's filter matches); non-glob
/// filters leave the listing unfiltered.
String _searchForFilter(FileChooserFilterMessage filter) {
  for (final pattern in filter.patterns) {
    if (pattern.kind == 0 && pattern.pattern.startsWith('*.')) {
      return pattern.pattern.substring(1);
    }
  }
  return '';
}
