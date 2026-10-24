import 'dart:convert';
import 'garment_render_metadata.dart';

/// Portable data, never executable instructions. All dimensions are ratios;
/// these describe appearance, not physical garment fit or size.
class GarmentModelMetadata {
  GarmentModelMetadata._(this.data);
  static const schema = 'bootic.garment-model/1';
  final Map<String, dynamic> data;
  static bool isModel(String text) {
    try {
      final value = jsonDecode(text);
      return value is Map && value['schema_version'] == schema;
    } on FormatException {
      return false;
    }
  }

  static GarmentModelMetadata parse(String text) {
    if (text.length > GarmentRenderMetadata.maxCharacters) {
      throw const FormatException('حجم مدل بیش از حد مجاز است');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic> ||
        decoded['schema_version'] != schema) {
      throw const FormatException('نسخهٔ مدل سه‌بعدی معتبر نیست');
    }
    final data = decoded;
    const keys = {
      'schema_version',
      'kind',
      'shape',
      'material',
      'source_metadata',
    };
    if (data.keys.any((k) => !keys.contains(k))) {
      throw const FormatException('فیلد ناشناخته در مدل سه‌بعدی');
    }
    if (!{'top', 'coat', 'dress', 'skirt', 'trousers'}.contains(data['kind'])) {
      throw const FormatException('نوع مدل سه‌بعدی معتبر نیست');
    }
    Map<String, dynamic> section(String key, Set<String> allowed) {
      final value = data[key];
      if (value is! Map<String, dynamic> ||
          value.keys.any((k) => !allowed.contains(k))) {
        throw FormatException('بخش $key معتبر نیست');
      }
      return value;
    }

    void ratio(Map<String, dynamic> map, String key, double min, double max) {
      final value = map[key];
      if (value is! num || !value.isFinite || value < min || value > max) {
        throw FormatException('نسبت $key باید بین $min و $max باشد');
      }
    }

    final shape = section('shape', {
      'length',
      'hem_width',
      'ease',
      'sleeve_length',
      'neck_width',
      'neck_depth',
      'neckline',
    });
    ratio(shape, 'length', 0.6, 2.2);
    ratio(shape, 'hem_width', 0.65, 1.8);
    ratio(shape, 'ease', 0, 0.25);
    ratio(shape, 'sleeve_length', 0, 1);
    ratio(shape, 'neck_width', 0.12, 0.32);
    ratio(shape, 'neck_depth', 0.02, 0.3);
    if (!{'round', 'v'}.contains(shape['neckline'])) {
      throw const FormatException('شکل یقه باید round یا v باشد');
    }
    final material = section('material', {
      'mode',
      'base_color',
      'accent_color',
      'pattern',
      'pattern_scale',
      'pattern_duty',
      'weave',
      'orientation',
      'roughness',
    });
    for (final key in ['base_color', 'accent_color']) {
      if (material[key] is! String ||
          !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(material[key] as String)) {
        throw FormatException('رنگ $key باید #RRGGBB باشد');
      }
    }
    if (!{'procedural', 'source'}.contains(material['mode']) ||
        !{'solid', 'stripes', 'checks'}.contains(material['pattern']) ||
        !{'horizontal', 'vertical'}.contains(material['orientation'])) {
      throw const FormatException('جنس یا طرح مدل پشتیبانی نمی‌شود');
    }
    ratio(material, 'pattern_scale', 0.005, 0.15);
    ratio(material, 'pattern_duty', 0.05, 0.95);
    if (!{'plain', 'knit', 'denim'}.contains(material['weave'])) {
      throw const FormatException('بافت پارچه پشتیبانی نمی‌شود');
    }
    ratio(material, 'roughness', 0.3, 1);
    if (material['mode'] == 'source') {
      final source = data['source_metadata'];
      if (source is! Map<String, dynamic> ||
          GarmentRenderMetadata.parse(jsonEncode(source)) == null) {
        throw const FormatException(
          'برای چاپ پیچیده، هندسهٔ معتبر عکس اصلی لازم است',
        );
      }
    } else if (data['source_metadata'] != null) {
      throw const FormatException('مدل پارامتری به هندسهٔ عکس نیاز ندارد');
    }
    return GarmentModelMetadata._(data);
  }

  Map<String, Object?> toNativeMap() => {
    ...data,
    if (data['source_metadata'] != null)
      'source_metadata': GarmentRenderMetadata.parse(
        jsonEncode(data['source_metadata']),
      )!.toNativeMap(),
  };
}
