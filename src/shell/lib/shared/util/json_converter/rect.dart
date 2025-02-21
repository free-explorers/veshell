import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

class RectConverter extends JsonConverter<Rect, Map<dynamic, dynamic>> {
  /// Serialize [Rect] to [Map].
  const RectConverter();

  @override
  Rect fromJson(Map<dynamic, dynamic> json) => Rect.fromLTWH(
        (json['x']! as num).toDouble(),
        (json['y']! as num).toDouble(),
        (json['width']! as num).toDouble(),
        (json['height']! as num).toDouble(),
      );

  @override
  Map<dynamic, dynamic> toJson(Rect object) => {
        'x': object.left,
        'y': object.top,
        'width': object.width,
        'height': object.height,
      };
}
