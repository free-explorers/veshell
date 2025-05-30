import 'package:json_annotation/json_annotation.dart';
import 'package:shell/platform/model/event/interactive_resize/interactive_resize.serializable.dart';

class ResizeEdgeConverter extends JsonConverter<ResizeEdge, int> {
  /// Serialize [ResizeEdge] to [int].
  const ResizeEdgeConverter();

  @override
  ResizeEdge fromJson(int index) => switch (index) {
        0 => ResizeEdge.none,
        1 => ResizeEdge.top,
        2 => ResizeEdge.bottom,
        4 => ResizeEdge.left,
        5 => ResizeEdge.topLeft,
        6 => ResizeEdge.bottomLeft,
        8 => ResizeEdge.right,
        9 => ResizeEdge.topRight,
        10 => ResizeEdge.bottomRight,
        _ => throw Exception('Invalid ResizeEdge index: $index'),
      };

  @override
  int toJson(ResizeEdge edge) => ResizeEdge.values.indexOf(edge);
}
