import 'dart:io';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_database.dart';
import 'package:store_app/data/garment_repository_impl.dart';
import 'package:store_app/domain/garment.dart';
import 'package:store_app/domain/field_definition.dart';

void main() {
  test(
    'v1 migration preserves catalog and settings and accepts actual SQL null',
    () async {
      final old = Garment.create(
        id: 'old',
        name: 'قدیمی',
      ).copyWith(price: 500, stock: 3, localRevision: 1);
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE garment_rows (id TEXT NOT NULL PRIMARY KEY,revision INTEGER NOT NULL,name TEXT NOT NULL,search_text TEXT NOT NULL,category TEXT NOT NULL,price INTEGER NOT NULL CHECK(price>=0),stock INTEGER NOT NULL CHECK(stock>=0),archived INTEGER NOT NULL DEFAULT 0,payload TEXT NOT NULL,updated_at INTEGER NOT NULL)',
            );
            raw.execute(
              'CREATE INDEX catalog_filter ON garment_rows(archived,category,updated_at)',
            );
            raw.execute(
              'CREATE TABLE setting_rows (key TEXT NOT NULL PRIMARY KEY,value TEXT NOT NULL)',
            );
            raw.execute(
              'CREATE TABLE schema_rows (key TEXT NOT NULL PRIMARY KEY,payload TEXT NOT NULL)',
            );
            raw.execute('PRAGMA user_version=1');
            raw.execute(
              'INSERT INTO garment_rows VALUES (?,?,?,?,?,?,?,?,?,?)',
              [
                old.id,
                1,
                old.name,
                '',
                old.category,
                500,
                3,
                0,
                jsonEncode(old.toJson()),
                0,
              ],
            );
            raw.execute(
              "INSERT INTO setting_rows VALUES ('activation','preserved')",
            );
          },
        ),
      );
      try {
        final repo = GarmentRepositoryImpl(db);
        var garment = (await repo.get('old'))!;
        expect(garment.price, 500);
        expect(garment.stock, 3);
        expect(await repo.readSetting('activation'), 'preserved');
        garment = await repo.save(
          garment.copyWith(clearPrice: true, clearStock: true),
          1,
        );
        final row = await db
            .customSelect('SELECT price,stock FROM garment_rows')
            .getSingle();
        expect(row.data['price'], isNull);
        expect(row.data['stock'], isNull);
        expect((await repo.get('old'))!.stock, isNull);
        garment = await repo.save(garment.copyWith(price: 0, stock: 0), 2);
        expect(garment.price, 0);
        expect(garment.stock, 0);
      } finally {
        await db.close();
      }
    },
  );

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
