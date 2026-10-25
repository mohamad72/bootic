import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/domain/garment_render_metadata.dart';
import 'package:store_app/presentation/garment_geometry_preview.dart';

void main() {
  String fixture() =>
      File('test/fixtures/striped_tshirt_metadata.json').readAsStringSync();

  test('torso region survives native conversion and remains optional', () {
    final data = jsonDecode(fixture()) as Map<String, dynamic>;
    final native = GarmentRenderMetadata.parse(jsonEncode(data))!.toNativeMap();
    expect(native['torso'], (data['regions'] as Map)['torso']['polygon_px']);
    (data['regions'] as Map).remove('torso');
    expect(
      GarmentRenderMetadata.parse(
        jsonEncode(data),
      )!.toNativeMap().containsKey('torso'),
      isFalse,
    );
  });

  testWidgets('source preview follows JSON edits and handles missing source', (
    tester,
  ) async {
    final controller = TextEditingController(text: fixture());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GarmentGeometryPreview(
              photoPath: 'missing-reference.jpg',
              controller: controller,
            ),
          ),
        ),
      ),
    );
    expect(find.text('بررسی مرزها روی عکس اصلی'), findsOneWidget);
    await tester.tap(find.text('بررسی مرزها روی عکس اصلی'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      .75,
    );
    expect(tester.takeException(), isNull);
    controller.text = '{';
    await tester.pump();
    expect(find.text('بررسی مرزها روی عکس اصلی'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
