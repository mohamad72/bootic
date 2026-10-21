import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app/providers.dart';
import 'app/store_app.dart';
import 'data/app_database.dart';
import 'data/garment_repository_impl.dart';
import 'data/local_asset_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final database = AppDatabase(
      NativeDatabase.createInBackground(
        File(p.join(directory.path, 'bootic.sqlite')),
      ),
    );
    final repository = GarmentRepositoryImpl(database);
    await repository.readSetting('storeName');
    runApp(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          assetStoreProvider.overrideWithValue(LocalAssetStore(directory)),
        ],
        child: const StoreApp(),
      ),
    );
  } catch (_) {
    runApp(const StartupFailureApp());
  }
}
