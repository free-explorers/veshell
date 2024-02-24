import 'dart:io';

import 'package:jovial_svg/jovial_svg.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_to_scalable_image.g.dart';

@Riverpod(keepAlive: true)
class FileToScalableImage extends _$FileToScalableImage {
  @override
  Future<ScalableImage> build(
    String path,
  ) async {
    final svg = await File(path).readAsString();
    return ScalableImage.fromSvgString(svg);
  }
}
