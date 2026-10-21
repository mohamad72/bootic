import 'dart:convert';
import 'package:drift/drift.dart';
import '../domain/field_definition.dart';
import '../domain/garment.dart';
import '../domain/garment_repository.dart';
import '../domain/persian.dart';
import 'app_database.dart';
export '../domain/garment_repository.dart' show RevisionConflict;

class GarmentRepositoryImpl implements GarmentRepository {
  GarmentRepositoryImpl(this.db);
  final AppDatabase db;

  @override
  Future<List<Garment>> list({
    String query = '',
    String? category,
    bool includeArchived = false,
  }) async {
    final statement = db.select(db.garmentRows)
      ..where(
        (t) =>
            includeArchived ? const Constant(true) : t.archived.equals(false),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (category != null) statement.where((t) => t.category.equals(category));
    final rows = await statement.get();
    final normalized = searchKey(query);
    return rows
        .where((row) => row.searchText.contains(normalized))
        .map(
          (row) =>
              Garment.fromJson(jsonDecode(row.payload) as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<Garment?> get(String id) async {
    final row = await (db.select(
      db.garmentRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : Garment.fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
  }

  @override
  Future<Garment> save(Garment garment, int expectedRevision) =>
      db.transaction(() async {
        final errors = garment.validate();
        if (errors.isNotEmpty) throw ArgumentError(errors.join('\n'));
        final definitions = [...baseFields, ...await fields()];
        for (final field in definitions) {
          if (!field.enabled || garment.excludedFields.contains(field.key)) {
            continue;
          }
          final error = field.validate(garment.metadata[field.key]);
          if (error != null) throw ArgumentError('${field.label}: $error');
        }
        final existing = await get(garment.id);
        if ((existing?.localRevision ?? 0) != expectedRevision ||
            (existing == null && expectedRevision != 0)) {
          throw RevisionConflict();
        }
        final saved = garment.copyWith(
          localRevision: expectedRevision + 1,
          updatedAt: DateTime.now().toUtc(),
        );
        final row = GarmentRowsCompanion.insert(
          id: saved.id,
          revision: saved.localRevision,
          name: saved.name,
          searchText: searchKey(
            '${saved.name} ${saved.sku} ${saved.barcode} ${saved.collection}',
          ),
          category: saved.category,
          price: saved.price,
          stock: saved.stock,
          archived: Value(saved.archived),
          payload: jsonEncode(saved.toJson()),
          updatedAt: saved.updatedAt,
        );
        if (existing == null) {
          await db.into(db.garmentRows).insert(row);
        } else {
          final count =
              await (db.update(db.garmentRows)..where(
                    (t) =>
                        t.id.equals(saved.id) &
                        t.revision.equals(expectedRevision),
                  ))
                  .write(row);
          if (count != 1) throw RevisionConflict();
        }
        return saved;
      });

  @override
  Future<void> archive(String id, int expectedRevision) async {
    final item = await get(id);
    if (item == null) throw RevisionConflict();
    await save(
      item.copyWith(archived: true, isActive: false),
      expectedRevision,
    );
  }

  @override
  Future<String?> readSetting(String key) async => (await (db.select(
    db.settingRows,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  @override
  Future<void> saveSetting(String key, String value) async {
    await db
        .into(db.settingRows)
        .insertOnConflictUpdate(
          SettingRowsCompanion.insert(key: key, value: value),
        );
  }

  @override
  Future<List<FieldDefinition>> fields() async =>
      (await db.select(db.schemaRows).get())
          .map(
            (row) => FieldDefinition.fromJson(
              jsonDecode(row.payload) as Map<String, dynamic>,
            ),
          )
          .toList();

  @override
  Future<void> saveField(FieldDefinition field) => db.transaction(() async {
    if (!field.key.startsWith('custom.') ||
        field.label.trim().isEmpty ||
        field.label.length > 80 ||
        field.options.length > 100 ||
        field.options.any((v) => v.trim().isEmpty || v.length > 80)) {
      throw ArgumentError('تعریف مشخصه معتبر نیست');
    }
    if ((field.type == FieldType.singleSelect ||
            field.type == FieldType.multiSelect) &&
        field.options.isEmpty) {
      throw ArgumentError('دست‌کم یک گزینه تعریف کنید');
    }
    final all = await fields();
    final previous = all.where((f) => f.key == field.key).firstOrNull;
    if (previous != null && previous.type != field.type) {
      throw ArgumentError('برای تغییر نوع، مشخصه تازه بسازید');
    }
    if (field.enabled &&
        !(previous?.enabled ?? false) &&
        all.where((f) => f.enabled).length >= 50) {
      throw ArgumentError('حداکثر ۵۰ مشخصه فعال مجاز است');
    }
    await db
        .into(db.schemaRows)
        .insertOnConflictUpdate(
          SchemaRowsCompanion.insert(
            key: field.key,
            payload: jsonEncode(field.toJson()),
          ),
        );
  });
}
