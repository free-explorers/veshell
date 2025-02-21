abstract class PersistableModel {
  factory PersistableModel.fromJson() {
    throw UnimplementedError();
  }
  Map<String, dynamic> toJson();
}
