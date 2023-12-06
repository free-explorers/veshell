import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

class SizeConverter extends JsonConverter<Size, Map<dynamic, dynamic>> {
  /// Serialize [Size] to [List].
  const SizeConverter();

  @override
  Size fromJson(Map<dynamic, dynamic> json) => Size(
        (json['width']! as num).toDouble(),
        (json['height']! as num).toDouble(),
      );

  @override
  Map<dynamic, dynamic> toJson(Size object) =>
      {'width': object.width, 'height': object.height};
}
