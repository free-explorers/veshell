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
///
/// The dialog takes the keyboard as soon as it opens: the save name is focused
/// with its base name selected, ready to be retyped, and the other modes focus
/// the search field, whose arrows move the selection and `Enter` opens it.
class FileChooserDialog extends HookConsumerWidget {
  /// constructor
  const FileChooserDialog({required this.request, super.key});

  /// The request being answered.
  final FileChooserRequestMessage request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const screenId = _fileChooserScreenId;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final explorer = ref.watch(fileExplorerStateProvider(screenId));
    final entryListAsync = ref.watch(filteredEntryListProvider(screenId));
    final entryList = entryListAsync.value ?? const <FileEntry>[];

    final isSave = request.mode == FileChooserMode.save;
    final isFolderPicker =
        request.mode == FileChooserMode.open && request.directory;

    // The selection is kept by path, not by index: filtering or re-sorting the
    // listing must never move the highlight onto another entry.
    final selectedPath = useState<DirectoryPath?>(null);
    final nameText = useState(_initialName(request));
    final searchText = useState('');
    final selectedFilter = useState<int?>(request.filters.isEmpty ? null : 0);
    final nameController = useTextEditingController(text: nameText.value);
    final searchController = useTextEditingController();
    final nameFocusNode = useFocusNode(debugLabel: 'FileChooserName');
    final searchFocusNode = useFocusNode(debugLabel: 'FileChooserSearch');

    final notifier = ref.read(fileExplorerStateProvider(screenId).notifier);
    final chooser = ref.read(fileChooserRequestProvider.notifier);

    // Seed the browser once per request: land on the requested folder (or
    // its fallback) without a surprise selection, prefill the save name, apply
    // the default type filter and take the keyboard.
    useEffect(() {
      selectedPath.value = null;
      nameText.value = _initialName(request);
      nameController.text = nameText.value;
      searchText.value = '';
      searchController.clear();
      selectedFilter.value = request.filters.isEmpty ? null : 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier
          ..setInitialLocation(
            DirectoryPath(_initialDirectory(request)),
            selected: _initialSelection(request),
          )
          ..setDirectoryOnly(isDirectoryOnly: isFolderPicker)
          ..setTypePatternList(
            request.filters.isEmpty
                ? const []
                : _patternsForFilter(request.filters.first),
          );
        if (!context.mounted) {
          return;
        }
        // The hosting tile keeps its own node focused, so `autofocus` would
        // never fire here: request the focus explicitly.
        if (isSave) {
          nameFocusNode.requestFocus();
          nameController.selection = _baseNameSelection(nameController.text);
        } else {
          searchFocusNode.requestFocus();
        }
      });
      return null;
    }, [request.consentToken]);

    // A stale selection never survives a change of directory.
    useEffect(() {
      selectedPath.value = null;
      return null;
    }, [explorer.path]);

    final selectedIndexOrMinus = selectedPath.value == null
        ? -1
        : entryList.indexWhere((entry) => entry.path == selectedPath.value);
    final selectedIndex = selectedIndexOrMinus < 0
        ? null
        : selectedIndexOrMinus;
    final selectedEntry = selectedIndex == null
        ? null
        : entryList[selectedIndex];

    void setName(String name) {
      nameText.value = name;
      nameController
        ..text = name
        ..selection = _baseNameSelection(name);
    }

    void select(int index) {
      if (index < 0 || index >= entryList.length) {
        return;
      }
      final entry = entryList[index];
      selectedPath.value = entry.path;
      if (isSave && !entry.isDirectory) {
        setName(entry.name);
      }
    }

    void approveFolder(DirectoryPath path) =>
        chooser.approve([_fileUri(path.path)]);

    void activate(int index) {
      if (index < 0 || index >= entryList.length) {
        return;
      }
      final entry = entryList[index];
      if (entry.isDirectory) {
        selectedPath.value = null;
        // Enter the folder without auto-selecting its first entry: the
        // chooser's save name must not change just from navigating. The
        // search is cleared so the new folder is shown unfiltered.
        searchText.value = '';
        searchController.clear();
        notifier.setInitialLocation(entry.path);
        return;
      }
      if (isSave) {
        select(index);
        nameFocusNode.requestFocus();
        return;
      }
      chooser.approve([_fileUri(entry.path.path)]);
    }

    /// Moves the selection by [delta] rows, from the top when none is set.
    void moveSelection(int delta) {
      if (entryList.isEmpty) {
        return;
      }
      final current = selectedIndex;
      final next = current == null
          ? (delta > 0 ? 0 : entryList.length - 1)
          : (current + delta).clamp(0, entryList.length - 1);
      select(next);
    }

    void accept() {
      switch (request.mode) {
        case FileChooserMode.open:
          if (request.directory) {
            approveFolder(
              selectedEntry != null && selectedEntry.isDirectory
                  ? selectedEntry.path
                  : explorer.path,
            );
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
      _ when isFolderPicker => context.l10n.selectFolder,
      _ =>
        request.mode == FileChooserMode.open
            ? context.l10n.open
            : context.l10n.save,
    };
    final title = request.title.isNotEmpty
        ? request.title
        : switch (request.mode) {
            FileChooserMode.open when request.directory =>
              context.l10n.selectFolder,
            FileChooserMode.open => context.l10n.openFile,
            FileChooserMode.save => context.l10n.saveFile,
            FileChooserMode.saveFiles => context.l10n.saveFiles,
          };

    final searchField = CallbackShortcuts(
      // Bound on the field itself so they win over the shell-wide bindings
      // (`Enter` is the global "activate" key).
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            moveSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            moveSelection(-1),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (selectedIndex != null) {
            activate(selectedIndex);
          } else if (entryList.isNotEmpty) {
            activate(0);
          }
        },
      },
      child: TextField(
        controller: searchController,
        focusNode: searchFocusNode,
        onChanged: (value) {
          searchText.value = value;
          // Typing narrows the list: start the keyboard from the first match.
          selectedPath.value = null;
        },
        decoration: _fieldDecoration(
          colorScheme,
          hintText: context.l10n.search,
          prefixIcon: const ShellIcon(MdiIcons.magnify, size: 20),
        ),
      ),
    );

    final typeFilter = request.filters.isEmpty
        ? null
        : SizedBox(
            width: 200,
            child: DropdownButtonFormField<int?>(
              initialValue: selectedFilter.value,
              isExpanded: true,
              decoration: _fieldDecoration(
                colorScheme,
                prefixIcon: const ShellIcon(MdiIcons.filterVariant, size: 20),
              ),
              items: [
                for (var i = 0; i < request.filters.length; i++)
                  DropdownMenuItem<int?>(
                    value: i,
                    child: Text(
                      request.filters[i].name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                DropdownMenuItem<int?>(child: Text(context.l10n.allFiles)),
              ],
              onChanged: (index) {
                selectedFilter.value = index;
                notifier.setTypePatternList(
                  index == null
                      ? const []
                      : _patternsForFilter(request.filters[index]),
                );
              },
            ),
          );

    return Card(
      color: colorScheme.surfaceContainer,
      child: CurrentScreenId(
        screenId: screenId,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): chooser.cancel,
          },
          child: Focus(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChooserHeader(
                    title: title,
                    appName: request.appName,
                    icon: switch (request.mode) {
                      FileChooserMode.open when request.directory =>
                        MdiIcons.folderOpen,
                      FileChooserMode.open => MdiIcons.fileSearch,
                      FileChooserMode.save ||
                      FileChooserMode.saveFiles => MdiIcons.contentSave,
                    },
                    onClose: chooser.cancel,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: searchField),
                      if (typeFilter != null) ...[
                        const SizedBox(width: 8),
                        typeFilter,
                      ],
                    ],
                  ),
                  if (request.mode == FileChooserMode.saveFiles &&
                      request.files.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      request.files.join(', '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FileExplorerView(
                          searchText: searchText.value,
                          selectedIndex: selectedIndex,
                          onSelect: select,
                          onActivate: activate,
                          onOpenDirectory: notifier.openBreadcrumb,
                          onOpenParent: notifier.openParentDirectory,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (isSave) ...[
                        Expanded(
                          child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(LogicalKeyboardKey.enter):
                                  accept,
                            },
                            child: TextField(
                              controller: nameController,
                              focusNode: nameFocusNode,
                              onChanged: (value) => nameText.value = value,
                              onSubmitted: (_) => accept(),
                              decoration: _fieldDecoration(
                                colorScheme,
                                labelText: context.l10n.fileName,
                                prefixIcon: const ShellIcon(
                                  MdiIcons.formTextbox,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else
                        const Spacer(),
                      TextButton(
                        onPressed: chooser.cancel,
                        child: Text(context.l10n.cancel),
                      ),
                      const SizedBox(width: 8),
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

/// The chooser's title row: a mode glyph, the title and requesting app, and
/// the close button.
class _ChooserHeader extends StatelessWidget {
  const _ChooserHeader({
    required this.title,
    required this.appName,
    required this.icon,
    required this.onClose,
  });

  final String title;
  final String appName;
  final IconData icon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: ShellIcon(icon, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (appName.isNotEmpty)
                Text(
                  appName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: context.l10n.close,
          onPressed: onClose,
          icon: const ShellIcon(MdiIcons.close),
        ),
      ],
    );
  }
}

/// The chooser's filled, rounded field style.
InputDecoration _fieldDecoration(
  ColorScheme colorScheme, {
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    prefixIcon: prefixIcon,
    isDense: true,
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    ),
  );
}

/// Selects the name without its extension (`report` in `report.pdf`), so
/// typing replaces the name and keeps the type; a name without an extension is
/// selected whole.
TextSelection _baseNameSelection(String name) {
  final dotIndex = name.lastIndexOf('.');
  return TextSelection(
    baseOffset: 0,
    extentOffset: dotIndex > 0 ? dotIndex : name.length,
  );
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

/// The explorer type patterns of a portal filter: its globs as-is and its
/// MIME types, both understood by the explorer's type matcher.
List<String> _patternsForFilter(FileChooserFilterMessage filter) => [
  for (final pattern in filter.patterns) pattern.pattern,
];
