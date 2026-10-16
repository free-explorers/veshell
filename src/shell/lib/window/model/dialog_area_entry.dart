import 'package:flutter/foundation.dart' show immutable;
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';

/// One entry shown in a tile's dialog area: a native dialog attached to the
/// tile, or the shell's trusted file chooser.
///
/// The area lists these in display order (dialogs by creation, the chooser
/// last), and selection is expressed as one of them (see
/// `selectedDialogForWindowProvider`).
@immutable
sealed class DialogAreaEntry {
  const DialogAreaEntry();

  /// Stable identity of the entry: the dialog's [DialogWindowId.uuid], or a
  /// fixed key for the single chooser entry.
  String get id;
}

/// A native dialog owned by the area's parent tile.
final class DialogWindowEntry extends DialogAreaEntry {
  const DialogWindowEntry(this.dialogWindowId);

  /// The dialog's shell window id.
  final DialogWindowId dialogWindowId;

  @override
  String get id => dialogWindowId.uuid;

  @override
  bool operator ==(Object other) =>
      other is DialogWindowEntry && other.dialogWindowId == dialogWindowId;

  @override
  int get hashCode => dialogWindowId.hashCode;

  @override
  String toString() => 'DialogWindowEntry(${dialogWindowId.uuid})';
}

/// The trusted file chooser requested by a window of the area's parent tile.
///
/// At most one chooser exists per tile, so it is a single virtual entry rather
/// than a real window; its request can be replaced without changing the entry.
final class FileChooserEntry extends DialogAreaEntry {
  const FileChooserEntry();

  /// Fixed key shared by every chooser entry.
  static const entryId = '__file_chooser__';

  @override
  String get id => entryId;

  @override
  bool operator ==(Object other) => other is FileChooserEntry;

  @override
  int get hashCode => entryId.hashCode;

  @override
  String toString() => 'FileChooserEntry()';
}

/// Whether the native window behind a dialog may be extracted to its own tile.
///
/// Only a regular top-level window qualifies. A window that declares a client
/// parent (`xdg_toplevel.set_parent`, X11 transient), is modal, or is fixed-size
/// is a genuine dialog — a portal chooser, an About box — and promoting it to a
/// tile makes no sense; a fixed-size window is also rendered by the floating
/// path, not the tabbed area. This is what keeps **Extract to new tile** off
/// real modal, portal and fixed-size dialogs while it stays available for a
/// top-level window that merely attached to the tile as a dialog.
bool isExtractableDialog(MetaWindow metaWindow) =>
    metaWindow.parent == null &&
    !metaWindow.isModal &&
    !metaWindow.isFixedSized;

/// Whether a dialog's native window keeps the tile's previous, floating
/// presentation instead of the tabbed dialog area.
///
/// A modal or fixed-size surface is drawn at its natural size: stretching it to
/// fill the tile — what the area's `maximized` geometry does — distorts a
/// fixed-size client and wastes the space for a modal one. Neither is ever a
/// candidate for extraction, so the tabbed area adds nothing, and such a dialog
/// floats over a dimmed tile exactly as it did before the area existed.
bool isFloatingDialog(MetaWindow metaWindow) =>
    metaWindow.isModal || metaWindow.isFixedSized;
