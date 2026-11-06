import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// How wide each frame is on a contact sheet.
const contactSheetCellWidth = 480;

/// The frames, as PNGs, in a grid of [columns] (scaled to
/// [contactSheetCellWidth]), each with its label in its corner.
Uint8List composeContactSheet(
  List<Uint8List> frames,
  List<String> labels, {
  int columns = 3,
}) {
  if (frames.isEmpty) {
    throw ArgumentError('No frames to lay out');
  }
  final decoded = [
    for (final frame in frames)
      img.copyResize(img.decodePng(frame)!, width: contactSheetCellWidth),
  ];
  final cellHeight = decoded.map((frame) => frame.height).reduce(math.max);
  const gap = 4;
  final columnCount = math.min(columns, decoded.length);
  final rowCount = (decoded.length / columnCount).ceil();
  final sheet = img.Image(
    width: columnCount * contactSheetCellWidth + (columnCount + 1) * gap,
    height: rowCount * cellHeight + (rowCount + 1) * gap,
    numChannels: 4,
  )..clear(img.ColorRgba8(32, 32, 32, 255));
  for (var index = 0; index < decoded.length; index++) {
    final left = gap + (index % columnCount) * (contactSheetCellWidth + gap);
    final top = gap + (index ~/ columnCount) * (cellHeight + gap);
    img.compositeImage(sheet, decoded[index], dstX: left, dstY: top);
    if (index < labels.length) {
      final label = labels[index];
      img.fillRect(
        sheet,
        x1: left,
        y1: top,
        x2: left + 8 + label.length * 8,
        y2: top + 20,
        color: img.ColorRgba8(0, 0, 0, 200),
      );
      img.drawString(
        sheet,
        label,
        font: img.arial14,
        x: left + 4,
        y: top + 3,
        color: img.ColorRgba8(255, 220, 0, 255),
      );
    }
  }
  return img.encodePng(sheet);
}
