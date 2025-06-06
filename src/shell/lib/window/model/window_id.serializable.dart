import 'package:freezed_annotation/freezed_annotation.dart';

part 'window_id.serializable.freezed.dart';
part 'window_id.serializable.g.dart';

@freezed
sealed class WindowId with _$WindowId {
  const factory WindowId.dialog(
    String uuid,
  ) = DialogWindowId;
  const factory WindowId.persistent(
    String uuid,
  ) = PersistentWindowId;
  const factory WindowId.ephemeral(
    String uuid,
  ) = EphemeralWindowId;

  factory WindowId.fromJson(Map<String, dynamic> json) =>
      _$WindowIdFromJson(json);
}

/* @immutable
sealed class WindowId {
  const WindowId(this._uuid);
  final String _uuid;

  @override
  String toString() => _uuid;

  @override
  bool operator ==(Object other) {
    if (other is String) {
      return other == _uuid;
    } else if (other is WindowId) {
      return other._uuid == _uuid;
    }
    return false;
  }

  @override
  int get hashCode => _uuid.hashCode;
}

class PersistentWindowId extends WindowId {
  const PersistentWindowId(super.uuid);
}

class DialogWindowId extends WindowId {
  const DialogWindowId(super.uuid);
}

class EphemeralWindowId extends WindowId {
  const EphemeralWindowId(super.uuid);
}

class PersistentWindowIdConverter
    extends JsonConverter<PersistentWindowId, String> {
  const PersistentWindowIdConverter();

  @override
  PersistentWindowId fromJson(String uuid) {
    return PersistentWindowId(uuid);
  }

  @override
  String toJson(PersistentWindowId object) => object.toString();
} */
