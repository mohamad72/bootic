import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_asset_store.dart';
import '../domain/garment_repository.dart';
import '../domain/garment.dart';
import '../domain/local_access.dart';
import '../domain/field_definition.dart';

final repositoryProvider = Provider<GarmentRepository>(
  (ref) => throw StateError('Repository not initialized'),
);
final assetStoreProvider = Provider<LocalAssetStore>(
  (ref) => throw StateError('Assets not initialized'),
);
final catalogProvider = FutureProvider<List<Garment>>(
  (ref) => ref.watch(repositoryProvider).list(),
);
final fieldsProvider = FutureProvider<List<FieldDefinition>>(
  (ref) async => [
    ...baseFields,
    ...await ref.watch(repositoryProvider).fields(),
  ],
);
final storeNameProvider = FutureProvider<String>(
  (ref) async =>
      await ref.watch(repositoryProvider).readSetting('storeName') ?? '',
);
final accessProvider = NotifierProvider<AccessController, bool>(
  AccessController.new,
);

class AccessController extends Notifier<bool> {
  @override
  bool build() => false;
  bool unlock(String code) {
    if (!LocalAccess.accepts(code)) return false;
    state = true;
    return true;
  }

  void lock() => state = false;
}
