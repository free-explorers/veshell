import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/file_chooser/model/file_chooser_request/file_chooser_request.serializable.dart';
import 'package:shell/file_chooser/provider/file_chooser_for_window.dart';
import 'package:shell/file_chooser/provider/file_chooser_request.dart';
import 'package:shell/file_chooser/widget/file_chooser_dialog.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/platform/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/widget/frosted_surface.dart';
import 'package:shell/shared/widget/panel_tab.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/window/model/dialog_area_entry.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/selected_dialog_for_window.dart';
import 'package:shell/window/widget/window.dart';
import 'package:shell/window/widget/window_dialogs.dart';

/// Fraction of a tile's shortest side left as a frosted margin around the
/// dialog panel.
///
/// A ratio rather than a fixed inset, so the margin shrinks with a small tile
/// (where a fixed value swallows the panel) and stays proportionate on a
/// large one.
const _panelMarginFactor = 0.06;

/// Height of the dialog tab bar, taken from `PanelTab`'s layout: a 40px action
/// button plus 8px of vertical padding on each side. Pre-computed rather than
/// measured so the content centring lands right on the first frame.
const _dialogTabBarHeight = 56.0;

/// The dialog area of a tile: the native windows attached to [parentWindowId]
/// that are regular top-levels (plus the trusted file chooser) presented as a
/// tabbed panel over the tile, whose content is blurred while the area is open.
///
/// A window the client declares a dialog — a client parent, a modal hint or a
/// fixed size — is not a tab: it floats at its natural size instead (see
/// `isFloatingDialog`).
///
/// Tiled instead of floated: only the selected entry is shown, filling the
/// panel's body, and the entries are navigated through the tab bar. The
/// selection lives in `selectedDialogForWindowProvider` so it survives the
/// panel remounting and is independent per tile.
class WindowDialogArea extends HookConsumerWidget {
  const WindowDialogArea({
    required this.parentWindowId,
    required this.child,
    this.dialogsEnabled = true,
    super.key,
  });

  /// The tile that owns the dialogs and the chooser; dialogs are matched to it
  /// and the selection is kept per tile.
  final WindowId parentWindowId;

  /// The tile's normal content, shown blurred behind the panel.
  final Widget child;

  /// When false the native dialogs are left out of the area (game mode still
  /// ignores them); the chooser is unaffected.
  final bool dialogsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialogIds = ref.watch(dialogSetForWindowProvider(parentWindowId));
    final chooser = ref.watch(fileChooserForWindowProvider(parentWindowId));

    // Split the dialogs by presentation, using the same predicate that offers
    // extraction: a regular top-level is a tab (and can be pulled out to a tile
    // of its own), while a window the client declares a dialog — a client
    // parent, modal or fixed-size — keeps the previous floating presentation
    // (see `isFloatingDialog`), drawn at its natural size over a dimmed tile.
    final areaDialogIds = <DialogWindowId>[];
    final floatingMetaWindowIds = <MetaWindowId>[];
    if (dialogsEnabled) {
      for (final dialogId in dialogIds) {
        final metaWindow = _readDialogMetaWindow(ref, dialogId);
        if (metaWindow != null && isFloatingDialog(metaWindow)) {
          floatingMetaWindowIds.add(metaWindow.id);
        } else {
          areaDialogIds.add(dialogId);
        }
      }
    }

    final entries = <DialogAreaEntry>[
      for (final dialogId in areaDialogIds) DialogWindowEntry(dialogId),
      if (chooser != null) const FileChooserEntry(),
    ];

    // A dialog that just opened, or a chooser that just arrived, takes the
    // selection: like the old floating stack, the newest window is the active
    // one. `ref.listen` (not a build-time write) keeps the notifier update
    // safe. A user's explicit tab pick is overridden by a new dialog, which is
    // the expected "a dialog just opened" behaviour. A floating dialog is not a
    // tab, so `_resolveSelection` simply ignores its entry.
    final selectionNotifier = ref.read(
      selectedDialogForWindowProvider(parentWindowId).notifier,
    );
    ref
      ..listen(dialogSetForWindowProvider(parentWindowId), (previous, next) {
        if (!dialogsEnabled || next.isEmpty) {
          return;
        }
        if (previous == null || next.length > previous.length) {
          selectionNotifier.select(DialogWindowEntry(next.last));
        }
      })
      ..listen(fileChooserForWindowProvider(parentWindowId), (previous, next) {
        if (next != null && next.consentToken != previous?.consentToken) {
          selectionNotifier.select(const FileChooserEntry());
        }
      });

    final stored = ref.watch(selectedDialogForWindowProvider(parentWindowId));
    final selected = _resolveSelection(stored, entries);
    final isOpen = selected != null;

    // One controller for the whole area: the backdrop's frost and the panel's
    // fade run together, so closing can no longer leave a frosted tile behind a
    // panel that already vanished. Fully used and symmetric (`frostCurve`), so
    // both directions start moving on the first frame.
    final frostController = useAnimationController(duration: frostDuration);
    final frostAnimation = useMemoized(
      () => CurvedAnimation(parent: frostController, curve: frostCurve),
      [frostController],
    );
    useEffect(() {
      if (isOpen) {
        frostController.forward();
      } else {
        frostController.reverse();
      }
      return null;
    }, [isOpen]);

    // A tile built while a dialog is already open (a workspace switch, a
    // monitor reconnect) must appear frosted rather than fade in: only a later
    // change of `isOpen` animates. The controller is still at its initial value
    // during this first build, so set it before anything listens.
    final settled = useRef(false);
    if (!settled.value) {
      settled.value = true;
      frostController.value = isOpen ? 1 : 0;
    }

    // The panel leaves with the frost: keep the last open state rendered (and
    // fading) until the backdrop has finished clearing, instead of unmounting
    // it the frame the dialog closes.
    final panelState =
        useRef<
          ({
            List<DialogAreaEntry> entries,
            DialogAreaEntry selected,
            FileChooserRequestMessage? chooser,
          })?
        >(null);
    if (selected != null) {
      panelState.value = (
        entries: entries,
        selected: selected,
        chooser: chooser,
      );
    }
    final panel = panelState.value;

    return Stack(
      fit: StackFit.expand,
      children: [
        _DialogAreaBackdrop(
          animation: frostAnimation,
          // The frosted backdrop is not interactive: clicks belong to the
          // panel, not to the window behind it.
          child: IgnorePointer(ignoring: isOpen, child: child),
        ),
        if (panel != null)
          AnimatedBuilder(
            animation: frostAnimation,
            builder: (context, child) {
              final progress = frostAnimation.value;
              if (progress <= 0) {
                // Fully closed: unmount the body so its surface is torn down.
                return const SizedBox.shrink();
              }
              return IgnorePointer(
                // A panel on its way out must not take clicks for a dialog that
                // is already closed.
                ignoring: !isOpen,
                // Fade only: scaling the panel would resample the live Wayland
                // surface it hosts (the whole-pixel contract).
                child: Opacity(opacity: progress, child: child),
              );
            },
            child: _DialogPanel(
              entries: panel.entries,
              selected: panel.selected,
              chooser: panel.chooser,
              onSelect: (entry) {
                selectionNotifier.select(entry);
                _activateEntry(ref, entry);
              },
            ),
          ),
        // A floating dialog stays on top of everything, exactly as it did
        // before the dialog area existed: the tile dims and the dialog floats
        // at its own size.
        if (floatingMetaWindowIds.isNotEmpty) ...[
          const Positioned.fill(child: ColoredBox(color: Colors.black38)),
          WindowDialogs(
            metaWindowIds: floatingMetaWindowIds,
            maxSizeFactor: 0.9,
          ),
        ],
      ],
    );
  }

  /// The stored selection when it still exists, otherwise the newest entry.
  static DialogAreaEntry? _resolveSelection(
    DialogAreaEntry? stored,
    List<DialogAreaEntry> entries,
  ) {
    if (entries.isEmpty) {
      return null;
    }
    if (stored != null) {
      for (final entry in entries) {
        if (entry.id == stored.id) {
          return entry;
        }
      }
    }
    return entries.last;
  }

  /// Hands the keyboard to the newly selected entry. A dialog is activated on
  /// the compositor, like a click into its surface would; the chooser drives
  /// its own focus, and a re-click of the current tab must still re-activate.
  void _activateEntry(WidgetRef ref, DialogAreaEntry entry) {
    if (entry is! DialogWindowEntry) {
      return;
    }
    final metaWindowId = _readDialogMetaWindowId(ref, entry.dialogWindowId);
    if (metaWindowId == null) {
      return;
    }
    final metaWindow = _readMetaWindow(ref, metaWindowId);
    if (metaWindow == null) {
      return;
    }
    unawaited(
      ref
          .read(platformManagerProvider.notifier)
          .request(
            ActivateWindowRequest(
              message: ActivateWindowMessage(
                surfaceId: metaWindow.surfaceId,
                activate: true,
              ),
            ),
          ),
    );
  }
}

/// The frosted tile layer. Renders the blur, vibrancy and wash from the area's
/// frost [animation], and leaves the tile untouched when it is at zero.
class _DialogAreaBackdrop extends StatelessWidget {
  const _DialogAreaBackdrop({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sigma grows with the region so a small tile is not over-blurred.
        final maxSigma = frostSigmaFor(constraints.biggest);
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final progress = animation.value;
            final scheme = Theme.of(context).colorScheme;
            // Cache the frosted result: while the panel is interacted with or
            // animated, the blur is reused instead of recomputed, as long as
            // the window behind it is not itself repainting.
            return RepaintBoundary(
              child: FrostedSurface(
                blurSigma: maxSigma * progress,
                // Match the overview's frost: blur plus a theme-hued wash. A
                // dark veil over a dark window (a terminal) just stayed black;
                // a wash that raises contrast lifts the window behind the
                // dialog and keeps the panel reading as the foreground.
                saturation: 1 + 0.20 * progress,
                // No wash while closed: without a dialog there is nothing to
                // frost, and the glass must not keep painting over the window.
                tint: progress > 0
                    ? frostedGlassTint(
                        scheme,
                      ).withAlpha((frostedWashAlpha * progress).round())
                    : null,
                tintOverContent: true,
                // The tile is not a card: no frame and no sheen at its edges.
                // The grain rides the ramp (it only paints once blurred) so it
                // fades with the wash instead of popping in.
                frame: false,
                highlight: false,
                noise: true,
                noiseOpacity: progress,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}

/// The panel itself: a tab bar and the selected entry.
///
/// The tab bar is a header, so it would push the body off-centre by its own
/// height. The top margin is reduced by that height instead, so the *content*
/// (the dialog) stays centred in the tile.
class _DialogPanel extends StatelessWidget {
  const _DialogPanel({
    required this.entries,
    required this.selected,
    required this.chooser,
    required this.onSelect,
  });

  final List<DialogAreaEntry> entries;
  final DialogAreaEntry selected;
  final FileChooserRequestMessage? chooser;
  final ValueChanged<DialogAreaEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A proportional margin through which the blurred window stays
        // visible: the panel is a portion of the tile, like the overview's
        // content pane, but a ratio keeps the margin from swallowing a small
        // tile the way a fixed inset does.
        //
        // Snapped to whole logical pixels: the body hosts a live Wayland
        // surface, and a decimal origin makes Flutter sample its external
        // texture bilinearly (an "always blurry" window).
        final margin = (constraints.biggest.shortestSide * _panelMarginFactor)
            .roundToDouble();
        // Subtract the tab bar's height from the top margin so the body — the
        // dialog itself — is what ends up centred, never past the tile edge.
        final top = (margin - _dialogTabBarHeight).clamp(0.0, double.infinity);
        return Padding(
          padding: EdgeInsets.only(
            top: top,
            bottom: margin,
            left: margin,
            right: margin,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // The chrome is click-only: keeping it out of the focus order
                // leaves the tile's own focus node in charge, so selecting a
                // tab (or pressing one of its actions) does not deactivate the
                // dialog it acts on. The body is left focusable for the
                // chooser's own autofocus.
                ExcludeFocus(
                  child: _DialogTabBar(
                    entries: entries,
                    selected: selected,
                    chooser: chooser,
                    onSelect: onSelect,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _DialogBody(selected: selected, chooser: chooser),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The row of dialog tabs, mirroring the overview content panel: horizontally
/// scrollable pills, only the selected one tinted.
class _DialogTabBar extends StatelessWidget {
  const _DialogTabBar({
    required this.entries,
    required this.selected,
    required this.chooser,
    required this.onSelect,
  });

  final List<DialogAreaEntry> entries;
  final DialogAreaEntry selected;
  final FileChooserRequestMessage? chooser;
  final ValueChanged<DialogAreaEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, entry) in entries.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              _DialogTab(
                entry: entry,
                chooser: chooser,
                isSelected: entry.id == selected.id,
                onTap: () => onSelect(entry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DialogTab extends ConsumerWidget {
  const _DialogTab({
    required this.entry,
    required this.chooser,
    required this.isSelected,
    required this.onTap,
  });

  final DialogAreaEntry entry;
  final FileChooserRequestMessage? chooser;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (entry) {
      DialogWindowEntry(:final dialogWindowId) => _dialogTab(
        context,
        ref,
        dialogWindowId,
      ),
      FileChooserEntry() => _chooserTab(context, ref),
    };
  }

  Widget _dialogTab(
    BuildContext context,
    WidgetRef ref,
    DialogWindowId dialogWindowId,
  ) {
    final dialog = ref.watch(dialogWindowStateProvider(dialogWindowId));

    // Extract is offered only for a regular top-level window attached as a
    // dialog, never for a real dialog: a modal one, or one declaring a parent
    // (a portal chooser, an About box). A dialog whose meta window is gone is
    // treated the same as a genuine dialog and gets no extract.
    var canExtract = false;
    try {
      canExtract = isExtractableDialog(
        ref.watch(metaWindowStateProvider(dialog.metaWindowId)),
      );
    } on Object {
      canExtract = false;
    }

    return PanelTab(
      icon: Padding(
        padding: const EdgeInsets.all(4),
        child: AppIconById(id: dialog.properties.appId),
      ),
      label: dialog.properties.title ?? context.l10n.unknown,
      isSelected: isSelected,
      onTap: onTap,
      trailingBuilder: (foregroundColor) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canExtract)
            _PillActionButton(
              color: foregroundColor,
              tooltip: context.l10n.extractToNewTile,
              icon: MdiIcons.openInNew,
              onPressed: () => unawaited(
                ref
                    .read(dialogWindowStateProvider(dialogWindowId).notifier)
                    .extractToTile(),
              ),
            ),
          _PillActionButton(
            color: foregroundColor,
            tooltip: context.l10n.close,
            icon: MdiIcons.close,
            onPressed: () => ref
                .read(metaWindowStateProvider(dialog.metaWindowId).notifier)
                .requestToClose(),
          ),
        ],
      ),
    );
  }

  Widget _chooserTab(BuildContext context, WidgetRef ref) {
    final chooser = this.chooser;
    return PanelTab(
      icon: const Padding(
        padding: EdgeInsets.all(4),
        child: ShellIcon(MdiIcons.folderOpen),
      ),
      label: chooser != null && chooser.title.isNotEmpty
          ? chooser.title
          : context.l10n.openFile,
      isSelected: isSelected,
      onTap: onTap,
      trailingBuilder: (foregroundColor) => _PillActionButton(
        color: foregroundColor,
        tooltip: context.l10n.close,
        icon: MdiIcons.close,
        onPressed: () => ref.read(fileChooserRequestProvider.notifier).cancel(),
      ),
    );
  }
}

/// A compact action inside a dialog pill: extract or close for a dialog,
/// cancel for the chooser.
///
/// Tinted with the pill's foreground so it reads on both the selected (filled)
/// and unselected pills. The pill's `InkWell` still handles taps outside the
/// icons, so an action never also selects the tab.
class _PillActionButton extends StatelessWidget {
  const _PillActionButton({
    required this.color,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Color color;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      color: color,
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: ShellIcon(icon, size: 16),
    );
  }
}

/// The selected entry's body: the dialog's surface filling the region, or the
/// trusted chooser.
class _DialogBody extends StatelessWidget {
  const _DialogBody({required this.selected, required this.chooser});

  final DialogAreaEntry selected;
  final FileChooserRequestMessage? chooser;

  @override
  Widget build(BuildContext context) {
    return switch (selected) {
      DialogWindowEntry(:final dialogWindowId) => _DialogWindowBody(
        key: ValueKey(dialogWindowId.uuid),
        dialogWindowId: dialogWindowId,
      ),
      FileChooserEntry() =>
        chooser == null
            ? const SizedBox.shrink()
            // The portal chooser fills the body, like a native dialog does.
            : FileChooserDialog(
                key: ValueKey(chooser!.consentToken),
                request: chooser!,
              ),
    };
  }
}

/// Renders a dialog's native surface filled into the region, reusing the
/// maximized tile path (undecorated, geometry re-asserted to the bounds).
class _DialogWindowBody extends HookConsumerWidget {
  const _DialogWindowBody({required this.dialogWindowId, super.key});

  final DialogWindowId dialogWindowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialog = ref.watch(dialogWindowStateProvider(dialogWindowId));

    // The dialog's surface must not hold the Flutter focus: the tile's single
    // focus node drives activation (see `WindowWidget.activationTarget`), and
    // two nodes fighting over it would activate one window and deactivate the
    // other. The node only exists because `MetaSurfaceWidget` expects one, and
    // keeping it non-focusable means the tile's node always wins.
    final focusNode = useFocusNode(debugLabel: 'DialogSurface $dialogWindowId')
      ..canRequestFocus = false;

    final window = WindowWidget(
      metaWindowId: dialog.metaWindowId,
      focusNode: focusNode,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Host the live surface at a whole-pixel size, pinned to the top-left
        // so its origin stays whole. A decimal size or origin makes Flutter
        // sample the external texture bilinearly (the same "always blurry"
        // trap the overview's split and the floating window's origin avoid).
        // The sub-pixel remainder is harmless; the blur is not.
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite) {
          return window;
        }
        return SizedBox(
          width: width.floorToDouble(),
          height: height.floorToDouble(),
          // The panel used to clip its body when it still drew a Material;
          // round the surface itself now so the dialog keeps the shell's
          // corner radius over the frosted tile. `ClipRRect` does not change
          // the size or origin the whole-pixel contract above relies on.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: window,
          ),
        );
      },
    );
  }
}

/// Reads a dialog's meta window during a build, or `null` when the dialog (or
/// its meta window) is not tracked yet. Both providers throw by design until
/// their state exists, which is why this is watched defensively.
MetaWindow? _readDialogMetaWindow(
  WidgetRef ref,
  DialogWindowId dialogWindowId,
) {
  try {
    final metaWindowId = ref
        .watch(dialogWindowStateProvider(dialogWindowId))
        .metaWindowId;
    return ref.watch(metaWindowStateProvider(metaWindowId));
  } on Object {
    return null;
  }
}

/// A dialog's meta window id, or `null` when the dialog is no longer tracked.
MetaWindowId? _readDialogMetaWindowId(WidgetRef ref, DialogWindowId windowId) {
  try {
    return ref.read(dialogWindowStateProvider(windowId)).metaWindowId;
  } on Object {
    return null;
  }
}

/// Reads a meta window, or `null` when it is gone.
MetaWindow? _readMetaWindow(WidgetRef ref, MetaWindowId metaWindowId) {
  try {
    return ref.read(metaWindowStateProvider(metaWindowId));
  } on Object {
    return null;
  }
}
