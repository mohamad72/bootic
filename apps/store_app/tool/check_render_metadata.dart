import 'dart:convert';
import 'dart:io';
import '../lib/domain/garment.dart';
import '../lib/domain/garment_render_metadata.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void rejects(String input) {
  try {
    GarmentRenderMetadata.parse(input);
  } on FormatException {
    return;
  }
  throw StateError('Invalid metadata was accepted');
}

void main() {
  final text = File(
    'test/fixtures/striped_tshirt_metadata.json',
  ).readAsStringSync();
  final metadata = GarmentRenderMetadata.parse(text)!;
  check(metadata.toNativeMap()['width'] == 1152, 'Source width changed');
  check(
    (metadata.toNativeMap()['holes'] as List).length == 1,
    'Neck opening lost',
  );
  check(
    (metadata.toNativeMap()['sleeves'] as List).length == 2,
    'Sleeve regions lost',
  );
  final g = Garment.create(id: 'test', name: 'تیشرت').copyWith(tryOnJson: text);
  final restored = Garment.fromJson(jsonDecode(jsonEncode(g.toJson())));
  check(restored.tryOnJson == text, 'Metadata was not persisted');
  check(
    restored.copyWith(name: 'ویرایش').tryOnJson == text,
    'Edit lost metadata',
  );
  check(
    g
        .copyWith(isDraft: false, photos: {'front': 'cutout.png'})
        .validate()
        .any((e) => e.contains('عکس اصلی')),
    'Publishing JSON without its source photo was accepted',
  );
  final old = g.toJson()..remove('tryOnJson');
  check(Garment.fromJson(old).tryOnJson.isEmpty, 'Legacy garment failed');
  check(
    GarmentRenderMetadata.parse('   ') == null,
    'Blank metadata is not optional',
  );
  rejects('{');
  rejects('[]');
  rejects('{"schema_version":"future"}');
  final invalid = jsonDecode(text) as Map<String, dynamic>;
  (invalid['landmarks_px'] as Map)['hem_center'] = [99999, 0];
  rejects(jsonEncode(invalid));
  check(
    g.copyWith(tryOnJson: '').tryOnJson.isEmpty,
    'Removing metadata failed',
  );
  print(
    'Metadata checks passed: sample schema, holes, sleeves, persistence, edits, legacy, removal and invalid input',
  );
}
