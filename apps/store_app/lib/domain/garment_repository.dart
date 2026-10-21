import 'field_definition.dart';
import 'garment.dart';

abstract interface class GarmentRepository {
  Future<List<Garment>> list({
    String query = '',
    String? category,
    bool includeArchived = false,
  });
  Future<Garment?> get(String id);
  Future<Garment> save(Garment garment, int expectedRevision);
  Future<void> archive(String id, int expectedRevision);
  Future<String?> readSetting(String key);
  Future<void> saveSetting(String key, String value);
  Future<List<FieldDefinition>> fields();
  Future<void> saveField(FieldDefinition field);
}

class RevisionConflict implements Exception {
  @override
  String toString() =>
      'این لباس در جای دیگری تغییر کرده است؛ صفحه را دوباره باز کنید';
}
