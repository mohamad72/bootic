import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/app/providers.dart';
import 'package:store_app/app/store_app.dart';
import 'package:store_app/data/app_database.dart';
import 'package:store_app/data/garment_repository_impl.dart';
import 'package:store_app/data/local_asset_store.dart';

void main() {
  testWidgets(
    'Persian offline setup, wrong code, saving draft and relocking preserve the catalog',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      final repo = GarmentRepositoryImpl(db);
      final temp = (await tester.runAsync(() => Directory.systemTemp.createTemp('bootic-ui-')))!;
      addTearDown(() async {
        await db.close();
        await temp.delete(recursive: true);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            assetStoreProvider.overrideWithValue(LocalAssetStore(temp)),
          ],
          child: const StoreApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
      );
      await tester.enterText(find.byKey(const Key('store-name')), 'بوتیک آبی');
      await tester.enterText(find.byKey(const Key('access-code')), '11111');
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();
      expect(find.text('کد ورود درست نیست'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('access-code')), '۲۲۲۲۲');
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();
      expect(find.text('بوتیک آبی'), findsWidgets);
      await tester.tap(find.byKey(const Key('add-garment')).first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('garment-name')),
        'مانتو کتان',
      );
      await tester.enterText(find.byKey(const Key('garment-price')), '۸۹۰۰۰۰');
      await tester.tap(find.byKey(const Key('save-draft')));
      await tester.pumpAndSettle();
      final saved = await repo.list();
      expect(saved.single.name, 'مانتو کتان');
      expect(saved.single.price, 890000);
      expect(saved.single.isDraft, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
