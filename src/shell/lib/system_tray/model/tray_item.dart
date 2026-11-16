import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tray_item.freezed.dart';

/// `Status` of a StatusNotifierItem.
enum TrayItemStatus {
  /// Nothing to report: hosts may hide the item.
  passive,

  /// The usual state.
  active,

  /// The application asks for attention; it may switch to its attention icon.
  needsAttention;

  static TrayItemStatus fromDbusValue(String? value) => switch (value) {
    'Passive' => passive,
    'NeedsAttention' => needsAttention,
    _ => active,
  };
}

/// One icon of an `a(iiay)` pixmap list, converted from the specification's
/// ARGB32 in network byte order to the RGBA8888 Flutter decodes.
@immutable
class TrayPixmap {
  TrayPixmap({required this.width, required this.height, required this.rgba})
    : _hash = Object.hash(width, height, Object.hashAll(rgba));

  final int width;
  final int height;
  final Uint8List rgba;
  final int _hash;

  @override
  bool operator ==(Object other) =>
      other is TrayPixmap &&
      other._hash == _hash &&
      other.width == width &&
      other.height == height &&
      listEquals(other.rgba, rgba);

  @override
  int get hashCode => _hash;
}

/// `ToolTip` of a StatusNotifierItem: `(sa(iiay)ss)`.
@freezed
abstract class TrayToolTip with _$TrayToolTip {
  const factory TrayToolTip({
    @Default('') String iconName,
    @Default(<TrayPixmap>[]) List<TrayPixmap> iconPixmaps,
    @Default('') String title,

    /// May carry a subset of HTML markup; see `plainToolTipText`.
    @Default('') String description,
  }) = _TrayToolTip;
}

/// A snapshot of one `org.kde.StatusNotifierItem`, rebuilt whenever the item
/// signals a change.
@freezed
abstract class TrayItem with _$TrayItem {
  const factory TrayItem({
    /// The watcher's item id: the bus name followed by the object path.
    required String id,
    required String busName,
    required String objectPath,

    /// The process behind [busName], resolved by the compositor.
    int? pid,

    /// `Category`: `ApplicationStatus`, `Communications`, `SystemServices`
    /// or `Hardware`.
    @Default('') String category,

    /// `Id`: a name the application gives its item, stable across runs.
    @Default('') String itemId,

    /// `Title`: the name the item is known by, e.g. the application's name.
    @Default('') String title,
    @Default(TrayItemStatus.active) TrayItemStatus status,
    @Default('') String iconName,
    @Default(<TrayPixmap>[]) List<TrayPixmap> iconPixmaps,
    @Default('') String attentionIconName,
    @Default(<TrayPixmap>[]) List<TrayPixmap> attentionIconPixmaps,

    /// `IconThemePath`: an extra icon-theme directory the icon names refer to.
    @Default('') String iconThemePath,
    TrayToolTip? toolTip,

    /// `ItemIsMenu`: the item only offers its menu, so a primary click opens
    /// it instead of calling `Activate`.
    @Default(false) bool itemIsMenu,

    /// `Menu`: the object path of the item's `com.canonical.dbusmenu`, if any.
    String? menuPath,
  }) = _TrayItem;

  const TrayItem._();

  /// The name the item is shown by: its title, its tooltip's title, or its id.
  String get label {
    for (final candidate in [title, toolTip?.title ?? '', itemId]) {
      if (candidate.trim().isNotEmpty) return candidate.trim();
    }
    return busName;
  }

  /// The icon name and pixmaps to draw in the item's current status: the
  /// attention icon while it needs attention and has one.
  ({String name, List<TrayPixmap> pixmaps}) get currentIcon =>
      status == TrayItemStatus.needsAttention &&
          (attentionIconName.isNotEmpty || attentionIconPixmaps.isNotEmpty)
      ? (name: attentionIconName, pixmaps: attentionIconPixmaps)
      : (name: iconName, pixmaps: iconPixmaps);
}
