abstract class PersistableModel {
  factory PersistableModel.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError();
  }
  Map<String, dynamic> toJson();
}
