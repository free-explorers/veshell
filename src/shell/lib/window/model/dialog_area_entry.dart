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

/// Whether the native window behind a dialog is a regular top-level window: one
/// the shell attached as a dialog rather than one the client declared as such.
///
/// A window that declares a client parent (`xdg_toplevel.set_parent`, X11
/// transient), is modal (`xdg_wm_dialog_v1`, X11 modal hints), or constrains
/// both axes to a single size is a genuine dialog — a portal chooser, an About
/// box. Only a regular top-level is tabbed in the dialog area and offered
/// **Extract to new tile**.
///
/// The area and the extraction action share this predicate on purpose: an entry
/// that could never leave the area is also not one the area should stretch, so
/// "tabbed" and "extractable" are the same set of windows.
bool isExtractableDialog(MetaWindow metaWindow) =>
    metaWindow.parent == null &&
    !metaWindow.isModal &&
    !metaWindow.isFixedSized;

/// Whether a dialog keeps the tile's previous, floating presentation instead of
/// becoming a tab in the dialog area.
///
/// The exact complement of [isExtractableDialog]: a client-declared dialog is
/// drawn at its natural size over a dimmed tile, because stretching it to fill
/// the panel — what the area's `maximized` geometry does — distorts a
/// fixed-size client and stretches a modal one beyond what it was designed for.
bool isFloatingDialog(MetaWindow metaWindow) =>
    !isExtractableDialog(metaWindow);
