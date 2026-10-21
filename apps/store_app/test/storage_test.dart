import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_database.dart';
import 'package:store_app/data/garment_repository_impl.dart';
import 'package:store_app/domain/garment.dart';
import 'package:store_app/domain/field_definition.dart';

void main() {
  test(
    'SQLite survives reopening and stale writes cannot overwrite current records',
    () async {
      final dir = await Directory.systemTemp.createTemp('bootic-test-');
      final file = File('${dir.path}/catalog.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      var repo = GarmentRepositoryImpl(db);
      try {
        var saved = await repo.save(
          Garment.create(id: 'a', name: 'پيراهن كتان').copyWith(price: 890000),
          0,
        );
        expect(saved.localRevision, 1);
        await repo.saveSetting('storeName', 'بوتیک تست');
        saved = await repo.save(saved.copyWith(stock: 5), 1);
        await expectLater(
          repo.save(saved.copyWith(stock: 9), 1),
          throwsA(isA<RevisionConflict>()),
        );
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        repo = GarmentRepositoryImpl(db);
        expect((await repo.get('a'))!.stock, 5);
        expect(await repo.readSetting('storeName'), 'بوتیک تست');
        expect((await repo.list(query: 'پیراهن کتان')).length, 1);
        await repo.archive('a', 2);
        expect(await repo.list(), isEmpty);
        expect((await repo.list(includeArchived: true)).length, 1);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'local schema revisions and disabled definitions preserve existing values',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = GarmentRepositoryImpl(db);
      try {
        const field = FieldDefinition(
          key: 'custom.x',
          label: 'جنس',
          type: FieldType.text,
        );
        await repo.saveField(field);
        final item = await repo.save(
          Garment.create(
            id: 'a',
            name: 'کت',
          ).copyWith(metadata: {'custom.x': 'کتان'}),
          0,
        );
        await repo.saveField(field.copyWith(enabled: false));
        expect((await repo.fields()).single.enabled, isFalse);
        expect((await repo.get(item.id))!.metadata['custom.x'], 'کتان');
        await expectLater(
          repo.saveField(
            const FieldDefinition(
              key: 'custom.x',
              label: 'جنس',
              type: FieldType.integer,
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      } finally {
        await db.close();
      }
    },
  );
}
