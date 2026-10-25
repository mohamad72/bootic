import 'dart:convert';
import 'dart:io';
import '../lib/domain/garment.dart';
import '../lib/domain/field_definition.dart';
import '../lib/domain/garment_ai_import.dart';
import '../lib/domain/garment_ai_prompt.dart';

int runAiImportChecks() {
  var checks = 0;
  void check(bool condition, String message) {
    checks++;
    if (!condition) throw StateError(message);
  }

  final geometry =
      jsonDecode(
            File(
              'test/fixtures/striped_tshirt_metadata.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final fields = [
    ...baseFields,
    const FieldDefinition(
      key: 'custom.size',
      label: 'سایز',
      type: FieldType.singleSelect,
      options: ['S', 'M', 'L'],
    ),
    const FieldDefinition(
      key: 'custom.count',
      label: 'شمار',
      type: FieldType.integer,
    ),
    const FieldDefinition(
      key: 'custom.rating',
      label: 'امتیاز',
      type: FieldType.score,
    ),
    const FieldDefinition(
      key: 'custom.disabled',
      label: 'غیرفعال',
      type: FieldType.text,
      enabled: false,
    ),
  ];
  Map<String, dynamic> payload() => {
    'schema_version': 'bootic.garment-import/1',
    'photo_id': 'reference.png',
    'garment': <String, dynamic>{
      'name': 'تیشرت راه‌راه',
      'category': 'top',
      'audience': 'unisex',
      'collection': null,
      'sku': null,
      'barcode': null,
      'price': null,
      'discountPrice': null,
      'stock': null,
      'isActive': null,
      'metadata': <String, dynamic>{
        'primaryColor': 'سفید',
        'pattern': 'راه‌راه',
        'styles': ['روزمره'],
        'custom.size': 'M',
        'custom.count': 2,
        'custom.rating': .8,
      },
      'measurements_mm': <String, dynamic>{'chest': null, 'length': null},
    },
    'try_on': jsonDecode(jsonEncode(geometry)),
  };
  GarmentAiImport parse(Map<String, dynamic> input) => GarmentAiImport.parse(
    jsonEncode(input),
    photoId: 'reference.png',
    width: 1152,
    height: 1536,
    fields: fields,
  );
  void rejects(Map<String, dynamic> input, String label) {
    try {
      parse(input);
    } on FormatException {
      checks++;
      return;
    }
    throw StateError('Invalid response accepted: $label');
  }

  final base = Garment.create(id: 'g', name: 'دستی').copyWith(
    price: 58000,
    stock: 7,
    discountPrice: 50000,
    sku: 'manual-sku',
    metadata: {'material': 'کتان', 'custom.old': 'نگه دار'},
    measurements: {'chest': 420},
    photos: {
      'front': 'garments/reference.png',
      'front_source': 'garments/reference.png',
    },
  );
  final published = base.copyWith(isDraft: false);
  check(
    published.validate().any((e) => e.contains('JSON')),
    'Publishing without JSON accepted',
  );
  check(
    !published.tryOnEligible,
    'Legacy image entered live try-on without JSON',
  );
  check(base.validate().isEmpty, 'Incomplete draft rejected');
  final before = jsonEncode(base.toJson());
  final imported = parse(payload()).applyTo(base);
  check(
    imported.name == 'تیشرت راه‌راه' && imported.audience == 'unisex',
    'Catalog properties not imported',
  );
  check(
    imported.price == 58000 &&
        imported.stock == 7 &&
        imported.discountPrice == 50000,
    'Unknown AI amounts overwrote manual values',
  );
  check(
    imported.measurements['chest'] == 420,
    'Unknown AI measurement erased manual value',
  );
  check(
    imported.metadata['material'] == 'کتان' &&
        imported.metadata['custom.old'] == 'نگه دار',
    'Unspecified manual metadata lost',
  );
  check(
    imported.metadata['pattern'] == 'راه‌راه' &&
        imported.metadata['custom.size'] == 'M',
    'Typed metadata did not populate',
  );
  check(
    jsonEncode(base.toJson()) == before,
    'Import mutated the original garment',
  );
  check(
    imported.tryOnJson == jsonEncode(geometry),
    'Render geometry was altered',
  );
  check(
    jsonDecode(imported.aiImportJson)['photo_id'] == 'reference.png',
    'Full response was not retained',
  );
  check(imported.isDraft, 'AI published without operator review');
  check(
    imported.copyWith(isDraft: false).tryOnEligible,
    'Valid JSON/source pair is not eligible',
  );
  check(
    imported.copyWith(isDraft: false, stock: 0).tryOnEligible == false,
    'Zero stock entered customer flow',
  );
  final noSource = imported.copyWith(
    isDraft: false,
    photos: {'front': 'cutout.png'},
  );
  check(
    noSource.validate().any((e) => e.contains('عکس اصلی')) &&
        !noSource.tryOnEligible,
    'Missing source accepted',
  );
  final archived = published.copyWith(archived: true, isActive: false);
  check(
    archived.validate().isEmpty,
    'Legacy item cannot be archived without deleting it',
  );
  final old = base.toJson()
    ..remove('audience')
    ..remove('aiImportJson')
    ..remove('tryOnJson');
  final legacy = Garment.fromJson(old);
  check(
    legacy.audience.isEmpty && legacy.aiImportJson.isEmpty,
    'Legacy payload failed to load',
  );
  final restored = Garment.fromJson(jsonDecode(jsonEncode(imported.toJson())));
  check(
    restored.audience == 'unisex' &&
        restored.tryOnJson == imported.tryOnJson &&
        restored.aiImportJson == imported.aiImportJson,
    'Round-trip lost new data',
  );
  for (final audience in garmentAudiences.keys) {
    final input = payload();
    (input['garment'] as Map)['audience'] = audience;
    check(
      parse(input).applyTo(base).audience == audience,
      'Audience $audience failed',
    );
  }
  final amounts = payload();
  (amounts['garment'] as Map).addAll(<String, dynamic>{
    'price': 100000,
    'discountPrice': 90000,
    'stock': 0,
    'isActive': false,
    'measurements_mm': {'chest': 450, 'length': 700},
  });
  final known = parse(amounts).applyTo(base);
  check(
    known.price == 100000 &&
        known.stock == 0 &&
        !known.isActive &&
        known.measurements['length'] == 700,
    'Explicit amounts/false/zero were ignored',
  );
  final unknownAudience = payload();
  (unknownAudience['garment'] as Map)['audience'] = null;
  check(
    parse(unknownAudience).applyTo(base.copyWith(audience: 'women')).audience ==
        'women',
    'Unknown audience overwrote manual group',
  );
  final fenced = GarmentAiImport.parse(
    '```json\n${jsonEncode(payload())}\n```',
    photoId: 'reference.png',
    width: 1152,
    height: 1536,
    fields: fields,
  );
  check(
    fenced.applyTo(base).name == imported.name,
    'Single fenced JSON not supported',
  );
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'wrong schema': (p) => p['schema_version'] = 'future',
    'stale photo': (p) => p['photo_id'] = 'other.png',
    'missing field': (p) => (p['garment'] as Map).remove('stock'),
    'extra field': (p) => (p['garment'] as Map)['execute'] = 'code',
    'negative stock': (p) => (p['garment'] as Map)['stock'] = -1,
    'decimal price': (p) => (p['garment'] as Map)['price'] = 12.5,
    'too many stock': (p) => (p['garment'] as Map)['stock'] = 1000000,
    'invalid audience': (p) => (p['garment'] as Map)['audience'] = 'unknown',
    'invalid category': (p) => (p['garment'] as Map)['category'] = 'invented',
    'invalid option': (p) =>
        (p['garment']['metadata'] as Map)['custom.size'] = 'XL',
    'wrong integer': (p) =>
        (p['garment']['metadata'] as Map)['custom.count'] = '2',
    'score outside range': (p) =>
        (p['garment']['metadata'] as Map)['custom.rating'] = 1.5,
    'disabled field': (p) =>
        (p['garment']['metadata'] as Map)['custom.disabled'] = 'bad',
    'unknown custom field': (p) =>
        (p['garment']['metadata'] as Map)['custom.missing'] = 'bad',
    'invalid measurement': (p) =>
        (p['garment']['measurements_mm'] as Map)['length'] = 0,
    'wrong dimensions': (p) =>
        (p['try_on']['source'] as Map)['width_px'] = 2000,
    'out of bounds': (p) =>
        (p['try_on']['landmarks_px'] as Map)['hem_center'] = [99999, 0],
    'missing render': (p) => p.remove('try_on'),
  }.entries) {
    final p = payload();
    mutation.value(p);
    rejects(p, mutation.key);
  }
  final badDiscount = payload();
  (badDiscount['garment'] as Map).addAll(<String, dynamic>{
    'price': 100,
    'discountPrice': 200,
  });
  var discountRejected = false;
  try {
    parse(badDiscount).applyTo(base);
  } on FormatException {
    discountRejected = true;
  }
  check(
    discountRejected && jsonEncode(base.toJson()) == before,
    'Commercial validation did not reject import atomically',
  );
  final prompt = GarmentAiPrompt.build(
    photoId: 'reference.png',
    width: 1152,
    height: 1536,
    fields: fields,
    knownValues: {'price': 58000},
  );
  check(
    prompt.contains('reference.png') &&
        prompt.contains('1152') &&
        prompt.contains('1536'),
    'Prompt omitted image identity/dimensions',
  );
  check(
    prompt.contains('custom.size') &&
        prompt.contains('"M"') &&
        !prompt.contains('custom.disabled'),
    'Prompt omitted active custom schema or included disabled fields',
  );
  check(
    prompt.contains('left_sleeve_hem_center') &&
        prompt.contains('outer_contour_px') &&
        prompt.contains(GarmentAiImport.schema),
    'Prompt omitted render/parser contract',
  );
  check(
    prompt.contains('58000') &&
        prompt.contains('Unknown') &&
        prompt.contains('TOMAN'),
    'Prompt omitted manual context and units',
  );
  print('AI form import: $checks checks passed');
  return checks;
}

void main() => runAiImportChecks();
