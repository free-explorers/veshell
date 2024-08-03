import 'package:freezed_annotation/freezed_annotation.dart';

part 'meta_bluez_adapter.freezed.dart';

@freezed
class MetaBluezAdapter with _$MetaBluezAdapter {
  factory MetaBluezAdapter({
    required bool powered,
    required bool discovering,
  }) = _MetaBluezAdapter;
}
