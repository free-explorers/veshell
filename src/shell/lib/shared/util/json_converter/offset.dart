import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

class OffsetConverter extends JsonConverter<Offset, Map<dynamic, dynamic>> {
  /// Serialize [Offset] to [Map].
  const OffsetConverter();

  @override
  Offset fromJson(Map<dynamic, dynamic> json) =>
      Offset((json['x']! as num).toDouble(), (json['y']! as num).toDouble());

  @override
  Map<dynamic, dynamic> toJson(Offset object) =>
      {'x': object.dx, 'y': object.dy};
}
