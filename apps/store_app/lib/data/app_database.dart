import 'package:drift/drift.dart';

part 'app_database.g.dart';

class GarmentRows extends Table {
  TextColumn get id => text()();
  IntColumn get revision => integer()();
  TextColumn get name => text()();
  TextColumn get searchText => text()();
  TextColumn get category => text()();
  // Drift generates the runtime getter; this declaration describes a SQL check.
  // ignore: recursive_getters
  IntColumn get price => integer().check(price.isBiggerOrEqualValue(0))();
  // ignore: recursive_getters
  IntColumn get stock => integer().check(stock.isBiggerOrEqualValue(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class SettingRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class SchemaRows extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [GarmentRows, SettingRows, SchemaRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX catalog_filter ON garment_rows(archived, category, updated_at)',
      );
    },
    onUpgrade: (m, from, to) async {
      throw StateError(
        'ارتقای این نسخه پایگاه داده پشتیبانی نمی‌شود؛ داده‌ها حفظ شدند',
      );
    },
    beforeOpen: (details) async {
      if (details.versionBefore != null &&
          details.versionBefore! > schemaVersion) {
        throw StateError('برای خواندن اطلاعات، برنامه را به‌روزرسانی کنید');
      }
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
