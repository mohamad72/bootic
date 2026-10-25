import 'dart:convert';
import 'dart:io';
import '../lib/domain/garment.dart';
import '../lib/domain/garment_model_metadata.dart';
import '../lib/domain/garment_ai_import.dart';
import '../lib/domain/garment_ai_prompt.dart';

Map<String, dynamic> modelFixture() => {
  'schema_version': GarmentModelMetadata.schema,
  'kind': 'top',
  'shape': {
    'length': 1.0,
    'hem_width': 1.0,
    'ease': 0.06,
    'sleeve_length': 0.35,
    'neck_width': 0.2,
    'neck_depth': 0.14,
    'neckline': 'round',
  },
  'material': {
    'mode': 'procedural',
    'base_color': '#EEE9DF',
    'accent_color': '#202638',
    'pattern': 'stripes',
    'pattern_scale': 0.05,
    'pattern_duty': 0.25,
    'weave': 'plain',
    'orientation': 'horizontal',
    'roughness': 0.85,
  },
  'source_metadata': null,
};
void main() {
  var count = 0;
  void check(bool condition, String label) {
    count++;
    if (!condition) throw StateError(label);
  }

  void rejects(Map<String, dynamic> model, String label) {
    try {
      GarmentModelMetadata.parse(jsonEncode(model));
    } on FormatException {
      count++;
      return;
    }
    throw StateError('Accepted invalid model: $label');
  }

  final blank = Garment.create(id: 'unknown', name: 'لباس');
  check(
    blank.price == null && blank.stock == null,
    'New values must be unknown',
  );
  final restored = Garment.fromJson(
    jsonDecode(jsonEncode(blank.toJson())) as Map<String, dynamic>,
  );
  check(
    restored.price == null && restored.stock == null,
    'Nulls lost on roundtrip',
  );
  final known = blank.copyWith(price: 1200, stock: 4);
  check(known.copyWith().price == 1200, 'copyWith preservation');
  check(
    known.copyWith(clearPrice: true, clearStock: true).price == null &&
        known.copyWith(clearStock: true).stock == null,
    'Manual clearing',
  );
  check(blank.copyWith(price: 0, stock: 0).price == 0, 'Explicit zero');
  check(
    blank.copyWith(discountPrice: 10).validate().isNotEmpty,
    'Discount needs base price',
  );
  final m = modelFixture();
  check(
    GarmentModelMetadata.parse(jsonEncode(m)).toNativeMap()['kind'] == 'top',
    'Native contract',
  );
  final photoGeometry = jsonDecode(
    File('test/fixtures/striped_tshirt_metadata.json').readAsStringSync(),
  );
  final procedural = blank.copyWith(tryOnJson: jsonEncode(m));
  check(
    procedural.renderMetadataError != null,
    'Procedural-only entries need photo geometry',
  );
  final published = blank.copyWith(
    tryOnJson: jsonEncode(photoGeometry),
    isDraft: false,
    photos: {'front': 'a.png', 'front_source': 'a.png'},
  );
  check(published.tryOnEligible, 'Unknown inventory must not hide garment');
  check(published.validate().isEmpty, 'Nulls must not block publication');
  check(!published.copyWith(stock: 0).tryOnEligible, 'Zero must hide garment');
  for (final kind in ['top', 'coat', 'dress', 'skirt', 'trousers']) {
    final model = modelFixture()..['kind'] = kind;
    check(
      GarmentModelMetadata.parse(jsonEncode(model)).data['kind'] == kind,
      'Missing kind',
    );
  }
  for (final key in [
    'length',
    'hem_width',
    'ease',
    'sleeve_length',
    'neck_width',
    'neck_depth',
  ]) {
    final model = modelFixture();
    (model['shape'] as Map)[key] = -1;
    rejects(model, key);
  }
  for (final e in <String, dynamic>{
    'base_color': 'red',
    'pattern': 'paisley',
    'mode': 'execute',
    'pattern_scale': 0,
    'pattern_duty': 1.0,
    'weave': 'silk',
    'roughness': 2,
  }.entries) {
    final model = modelFixture();
    (model['material'] as Map)[e.key] = e.value;
    rejects(model, e.key);
  }
  final badSource = modelFixture();
  (badSource['material'] as Map)['mode'] = 'source';
  rejects(badSource, 'source geometry');
  final payload = {
    'schema_version': GarmentAiImport.schema,
    'photo_id': 'ref.png',
    'garment': {
      'name': 'تی‌شرت',
      'category': 'top',
      'audience': null,
      'collection': null,
      'sku': null,
      'barcode': null,
      'price': null,
      'discountPrice': null,
      'stock': null,
      'isActive': null,
      'metadata': <String, dynamic>{},
      'measurements_mm': <String, dynamic>{},
    },
    'try_on': photoGeometry,
  };
  GarmentAiImport parse() => GarmentAiImport.parse(
    jsonEncode(payload),
    photoId: 'ref.png',
    width: 1152,
    height: 1536,
    fields: [],
  );
  final applied = parse().applyTo(blank);
  final sourceModel = modelFixture();
  (sourceModel['material'] as Map)['mode'] = 'source';
  sourceModel['source_metadata'] = jsonDecode(
    File('test/fixtures/striped_tshirt_metadata.json').readAsStringSync(),
  );
  check(
    GarmentModelMetadata.parse(
          jsonEncode(sourceModel),
        ).photoMetadata().toNativeMap()['schema'] ==
        'bootic.garment-metadata/0.1',
    'Legacy source photo conversion',
  );
  check(
    (GarmentModelMetadata.parse(
              jsonEncode(sourceModel),
            ).toNativeMap()['source_metadata']
            as Map)['schema'] ==
        'bootic.garment-metadata/0.1',
    'Source native geometry conversion',
  );
  final sourcePayload = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
  sourcePayload['try_on'] = sourceModel;
  check(
    GarmentAiImport.parse(
      jsonEncode(sourcePayload),
      photoId: 'ref.png',
      width: 1152,
      height: 1536,
      fields: [],
    ).renderJson.isNotEmpty,
    'Source model import',
  );
  var wrongDimensions = false;
  try {
    GarmentAiImport.parse(
      jsonEncode(sourcePayload),
      photoId: 'ref.png',
      width: 512,
      height: 768,
      fields: [],
    );
  } on FormatException {
    wrongDimensions = true;
  }
  check(wrongDimensions, 'Source model accepted wrong photo dimensions');
  check(applied.price == null && applied.stock == null, 'AI unknown numbers');
  check(
    parse().applyTo(known).stock == 4 && parse().applyTo(known).price == 1200,
    'AI null preserves manual',
  );
  (payload['garment'] as Map)['price'] = 0;
  (payload['garment'] as Map)['stock'] = 0;
  check(
    parse().applyTo(blank).stock == 0 && parse().applyTo(blank).price == 0,
    'AI zero',
  );
  payload['try_on'] = modelFixture();
  var mismatch = false;
  try {
    parse().applyTo(blank);
  } on FormatException {
    mismatch = true;
  }
  check(mismatch, 'Procedural rendering must be rejected');
  final prompt = GarmentAiPrompt.build(
    photoId: 'ref.png',
    width: 512,
    height: 768,
    fields: [],
  );
  check(
    !prompt.contains(GarmentModelMetadata.schema) &&
        prompt.contains(GarmentAiImport.schema),
    'Prompt schema',
  );
  check(
    prompt.contains('outer_contour_px') &&
        prompt.contains('Do not convert unknown numbers to zero'),
    'Prompt null instructions',
  );
  check(jsonEncode(blank.toJson()).contains('"price":null'), 'Payload null');
  print('Garment model/null values: $count checks passed');
}
