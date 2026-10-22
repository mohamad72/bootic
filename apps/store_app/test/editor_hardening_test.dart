import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:store_app/app/providers.dart';
import 'package:store_app/domain/field_definition.dart';
import 'package:store_app/domain/garment.dart';
import 'package:store_app/domain/garment_repository.dart';
import 'package:store_app/presentation/dynamic_field.dart';
import 'package:store_app/presentation/garment_editor_screen.dart';

class _Repository implements GarmentRepository {
  final saved = <Garment>[];
  Completer<void>? holdFirstSave;

  @override
  Future<Garment> save(Garment garment, int expectedRevision) async {
    if (saved.isEmpty && holdFirstSave != null) await holdFirstSave!.future;
    final result = garment.copyWith(localRevision: expectedRevision + 1);
    saved.add(result);
    return result;
  }

  @override
  Future<List<FieldDefinition>> fields() async => [];
  @override
  Future<Garment?> get(String id) async => null;
  @override
  Future<List<Garment>> list({
    String query = '',
    String? category,
    bool includeArchived = false,
  }) async => saved;
  @override
  Future<void> archive(String id, int expectedRevision) async {}
  @override
  Future<String?> readSetting(String key) async => null;
  @override
  Future<void> saveSetting(String key, String value) async {}
  @override
  Future<void> saveField(FieldDefinition field) async {}
}

Future<GoRouter> _pumpEditor(
  WidgetTester tester,
  _Repository repository, {
  Future<List<FieldDefinition>> Function()? definitions,
  bool compact = false,
}) async {
  tester.view.physicalSize = compact
      ? const Size(360, 900)
      : const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(path: '/edit', builder: (_, _) => const GarmentEditorScreen()),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        if (definitions != null)
          fieldsProvider.overrideWith((ref) => definitions()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: compact
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              )
            : null,
      ),
    ),
  );
  await tester.pump();
  return router;
}

void main() {
  testWidgets('valid manual render JSON is included in the saved garment', (
    tester,
  ) async {
    final repo = _Repository();
    await _pumpEditor(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('garment-name')), 'تیشرت');
    final field = find.byKey(const Key('garment-render-json'));
    await tester.ensureVisible(field);
    final text = File(
      'test/fixtures/striped_tshirt_metadata.json',
    ).readAsStringSync();
    await tester.enterText(field, text);
    await tester.pump(const Duration(seconds: 2));
    expect(repo.saved.last.tryOnJson, text);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid manual render JSON blocks autosave with an inline error',
    (tester) async {
      final repo = _Repository();
      await _pumpEditor(tester, repo);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('garment-name')), 'تیشرت');
      final field = find.byKey(const Key('garment-render-json'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '{');
      await tester.pump(const Duration(seconds: 2));
      expect(repo.saved, isEmpty);
      expect(find.textContaining('ساختار JSON معتبر نیست'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('save is disabled until field definitions load', (tester) async {
    final fields = Completer<List<FieldDefinition>>();
    await _pumpEditor(tester, _Repository(), definitions: () => fields.future);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('save-draft')))
          .onPressed,
      isNull,
    );
    fields.complete([]);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('save-draft')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('save remains disabled when field definitions fail', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      _Repository(),
      definitions: () async => throw StateError('schema unavailable'),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('save-draft')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('discard dialog pauses autosave and stay resumes it', (
    tester,
  ) async {
    final repo = _Repository();
    await _pumpEditor(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('garment-name')), 'کت');
    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(repo.saved, isEmpty);
    await tester.tap(find.text('ادامه ویرایش'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(repo.saved.single.name, 'کت');
  });

  testWidgets('exit without saving never commits the pending edit', (
    tester,
  ) async {
    final repo = _Repository();
    await _pumpEditor(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('garment-name')), 'کت');
    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('خروج بدون ذخیره'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(repo.saved, isEmpty);
  });

  testWidgets('editor fits 360dp width with 1.5 text scale', (tester) async {
    await _pumpEditor(tester, _Repository(), compact: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-draft')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edits during explicit save are persisted before exit', (
    tester,
  ) async {
    final repo = _Repository()..holdFirstSave = Completer<void>();
    await _pumpEditor(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('garment-name')), 'اول');
    await tester.tap(find.byKey(const Key('save-draft')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('garment-name')), 'آخر');
    repo.holdFirstSave!.complete();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(repo.saved.last.name, 'آخر');
  });

  testWidgets('save and exit includes edits made during its pending write', (
    tester,
  ) async {
    final repo = _Repository()..holdFirstSave = Completer<void>();
    await _pumpEditor(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('garment-name')), 'اول');
    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pump();
    await tester.tap(find.text('ذخیره و خروج'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('garment-name')), 'آخر');
    repo.holdFirstSave!.complete();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(repo.saved.last.name, 'آخر');
  });

  testWidgets(
    'out of range stored date stays editable and reports validation',
    (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: key,
              child: DynamicField(
                definition: const FieldDefinition(
                  key: 'date',
                  label: 'تاریخ',
                  type: FieldType.date,
                ),
                value: '9999-01-01',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('9999-01-01'), findsOneWidget);
      expect(key.currentState!.validate(), isFalse);
    },
  );
}
