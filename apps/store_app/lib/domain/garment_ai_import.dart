import 'dart:convert';
import 'field_definition.dart';
import 'garment.dart';
import 'garment_render_metadata.dart';
import 'garment_model_metadata.dart';

/// Validates the entire response before exposing any form changes.
/// null means unknown: it never clears an operator's existing value.
class GarmentAiImport {
  GarmentAiImport._(this.sourceJson, this.values, this.renderJson);
  static const schema = 'bootic.garment-import/2';
  final String sourceJson, renderJson;
  final Map<String, dynamic> values;

  static GarmentAiImport parse(
    String text, {
    required String photoId,
    required int width,
    required int height,
    required List<FieldDefinition> fields,
  }) {
    if (text.length > GarmentRenderMetadata.maxCharacters) {
      throw const FormatException('حجم پاسخ بیش از حد مجاز است');
    }
    var input = text.trim();
    // Accept one complete JSON code block, never extract a guessed substring.
    if (input.startsWith('```')) {
      final match = RegExp(
        r'^```(?:json)?\s*\n([\s\S]*?)\n```$',
        caseSensitive: false,
      ).firstMatch(input);
      if (match == null)
        throw const FormatException('فقط یک JSON کامل وارد کنید');
      input = match[1]!.trim();
    }
    Object? decoded;
    try {
      decoded = jsonDecode(input);
    } on FormatException {
      throw const FormatException('پاسخ، JSON معتبر نیست');
    }
    Map<String, dynamic> object(Object? value, String label) {
      if (value is! Map<String, dynamic>)
        throw FormatException('بخش $label باید یک شیء باشد');
      return value;
    }

    void keys(Map<String, dynamic> map, Set<String> allowed, String label) {
      if (map.keys.any((key) => !allowed.contains(key)))
        throw FormatException(
          'فیلد ناشناخته در $label؛ با پرامپت همین فرم خروجی بگیرید',
        );
    }

    final root = object(decoded, 'پاسخ');
    keys(root, {'schema_version', 'photo_id', 'garment', 'try_on'}, 'پاسخ');
    if (root['schema_version'] != schema &&
        root['schema_version'] != 'bootic.garment-import/1')
      throw const FormatException(
        'نسخهٔ پاسخ باید bootic.garment-import/1 باشد',
      );
    if (photoId.isEmpty || root['photo_id'] != photoId)
      throw const FormatException(
        'این پاسخ متعلق به عکس فعلی نیست؛ پرامپت همین عکس را دوباره کپی کنید',
      );
    final data = object(root['garment'], 'garment');
    const allowed = {
      'name',
      'category',
      'audience',
      'collection',
      'sku',
      'barcode',
      'price',
      'discountPrice',
      'stock',
      'isActive',
      'metadata',
      'measurements_mm',
    };
    keys(data, allowed, 'garment');
    if (!allowed.every(data.containsKey))
      throw const FormatException(
        'بخش garment ناقص است؛ فیلدهای نامعلوم را null بگذارید',
      );
    for (final entry in {
      'name': 120,
      'collection': 500,
      'sku': 200,
      'barcode': 200,
    }.entries) {
      final value = data[entry.key];
      if (value != null &&
          (value is! String ||
              value.length > entry.value ||
              value.trim().isEmpty))
        throw FormatException(
          'مقدار ${entry.key} نامعتبر است؛ برای نامعلوم null بگذارید',
        );
    }
    if (data['category'] != null &&
        !garmentCategories.containsKey(data['category']))
      throw const FormatException('دستهٔ لباس در پاسخ معتبر نیست');
    if (data['audience'] != null &&
        !garmentAudiences.containsKey(data['audience']))
      throw const FormatException(
        'گروه مردانه/زنانه/کودک/یونیسکس در پاسخ معتبر نیست',
      );
    for (final key in ['price', 'discountPrice', 'stock']) {
      final value = data[key];
      final max = key == 'stock' ? 999999 : 999999999999;
      if (value != null && (value is! int || value < 0 || value > max))
        throw FormatException(
          'مقدار $key باید عدد صحیح نامنفی در محدودهٔ مجاز باشد',
        );
    }
    if (data['isActive'] != null && data['isActive'] is! bool)
      throw const FormatException(
        'وضعیت فعال بودن باید true، false یا null باشد',
      );
    final definitions = {
      for (final field in fields.where((f) => f.enabled)) field.key: field,
    };
    final metadata = object(data['metadata'], 'metadata');
    for (final entry in metadata.entries) {
      final field = definitions[entry.key];
      if (field == null)
        throw FormatException('مشخصهٔ ${entry.key} در فرم فعلی وجود ندارد');
      if (entry.value != null && field.validate(entry.value) != null)
        throw FormatException('${field.label}: ${field.validate(entry.value)}');
    }
    final measurements = object(data['measurements_mm'], 'measurements_mm');
    keys(measurements, {'chest', 'length'}, 'اندازه‌ها');
    for (final entry in measurements.entries) {
      final v = entry.value;
      if (v != null && (v is! num || !v.isFinite || v <= 0 || v > 10000))
        throw FormatException('اندازهٔ ${entry.key} معتبر نیست');
    }
    final render = object(root['try_on'], 'try_on');
    final renderJson = jsonEncode(render);
    final model = GarmentModelMetadata.isModel(renderJson)
        ? GarmentModelMetadata.parse(renderJson)
        : null;
    if (model == null) GarmentRenderMetadata.parse(renderJson);
    final sourceRender = model == null ? render : model.data['source_metadata'];
    if (sourceRender != null) {
      final source = object((sourceRender as Map)['source'], 'try_on.source');
      if (source['width_px'] != width || source['height_px'] != height) {
        throw const FormatException('ابعاد هندسه با عکس مرجع هماهنگ نیست');
      }
    }
    return GarmentAiImport._(jsonEncode(root), data, renderJson);
  }

  Garment applyTo(Garment current) {
    String? string(String key) => (values[key] as String?)?.trim();
    final metadata = Map<String, Object?>.of(current.metadata);
    for (final e in (values['metadata'] as Map<String, dynamic>).entries) {
      if (e.value != null) metadata[e.key] = e.value;
    }
    final measurements = Map<String, double>.of(current.measurements);
    for (final e
        in (values['measurements_mm'] as Map<String, dynamic>).entries) {
      if (e.value != null) measurements[e.key] = (e.value as num).toDouble();
    }
    final result = current.copyWith(
      name: string('name'),
      category: string('category'),
      audience: string('audience'),
      collection: string('collection'),
      sku: string('sku'),
      barcode: string('barcode'),
      price: values['price'] as int?,
      discountPrice: values['discountPrice'] as int?,
      stock: values['stock'] as int?,
      isActive: values['isActive'] as bool?,
      metadata: metadata,
      measurements: measurements,
      tryOnJson: renderJson,
      aiImportJson: sourceJson,
      // AI fills a reviewable draft; only the operator publishes it.
      isDraft: true,
    );
    if (GarmentModelMetadata.isModel(renderJson) &&
        GarmentModelMetadata.parse(renderJson).data['kind'] !=
            result.category) {
      throw const FormatException('نوع مدل سه‌بعدی با دستهٔ لباس هماهنگ نیست');
    }
    final errors = result.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    return result;
  }
}
