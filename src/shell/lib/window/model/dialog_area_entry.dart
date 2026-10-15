import 'package:flutter/foundation.dart' show immutable;
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
