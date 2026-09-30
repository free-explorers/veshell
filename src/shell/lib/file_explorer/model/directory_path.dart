import 'package:freezed_annotation/freezed_annotation.dart';

part 'directory_path.freezed.dart';

/// A normalised absolute path to a directory in the local filesystem.
///
/// A value type so it can key Riverpod providers: two equal paths are the same
/// directory. Helpers ([name], [parent], [breadcrumb]) are pure and shared by
/// the state and the breadcrumb bar.
@freezed
abstract class DirectoryPath with _$DirectoryPath {
  const factory DirectoryPath(String path) = _DirectoryPath;
  const DirectoryPath._();

  /// The last path segment, or `/` for the filesystem root.
  String get name {
    final segmentList = _segmentList;
    return segmentList.isEmpty ? '/' : segmentList.last;
  }

  /// The parent directory, or `null` when this is the filesystem root.
  DirectoryPath? get parent {
    final segmentList = _segmentList;
    if (segmentList.isEmpty) {
      return null;
    }
    segmentList.removeLast();
    return DirectoryPath('/${segmentList.join('/')}');
  }

  /// Every ancestor of this path as a cumulative breadcrumb.
  List<({String name, DirectoryPath path})> get breadcrumb {
    final segmentList = _segmentList;
    final breadcrumbList = <({String name, DirectoryPath path})>[];
    final accumulatedPath = StringBuffer();
    for (final segment in segmentList) {
      accumulatedPath
        ..write('/')
        ..write(segment);
      breadcrumbList.add((
        name: segment,
        path: DirectoryPath(accumulatedPath.toString()),
      ));
    }
    return breadcrumbList;
  }

  /// The non-empty path segments.
  List<String> get _segmentList =>
      path.split('/')..removeWhere((segment) => segment.isEmpty);
}
