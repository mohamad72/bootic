import 'dart:convert';

/// The complete JSON is stored on Garment. This parser extracts only the
/// numerical, supported rendering data; instruction strings are never executed.
class GarmentRenderMetadata {
  GarmentRenderMetadata._(this._native);
  static const maxCharacters = 1024 * 1024;
  static const schema = 'bootic.garment-metadata/0.1';
  final Map<String, Object?> _native;
  Map<String, Object?> toNativeMap() => _native;

  static GarmentRenderMetadata? parse(String text) {
    if (text.trim().isEmpty) return null;
    if (text.length > maxCharacters) {
      throw const FormatException('حجم JSON بیش از حد مجاز است');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException(
        'ساختار JSON معتبر نیست؛ متن کامل را کپی کنید',
      );
    }
    Map<String, dynamic> object(Object? value, String field) {
      if (value is! Map<String, dynamic>) {
        throw FormatException('بخش $field باید یک شیء JSON باشد');
      }
      return value;
    }

    final root = object(decoded, 'اصلی');
    if (root['schema_version'] != schema) {
      throw const FormatException(
        'نسخهٔ JSON پشتیبانی نمی‌شود؛ نسخهٔ bootic.garment-metadata/0.1 لازم است',
      );
    }
    final source = object(root['source'], 'source');
    double dimension(String key) {
      final n = source[key];
      if (n is! num || !n.isFinite || n < 64 || n > 6000) {
        throw FormatException('مقدار source.$key باید بین ۶۴ و ۶۰۰۰ باشد');
      }
      return n.toDouble();
    }

    final width = dimension('width_px'), height = dimension('height_px');
    if (source['points_convention'] !=
        'image_left/image_right; not anatomical left/right') {
      throw const FormatException('جهت نقاط باید بر اساس چپ و راست عکس باشد');
    }
    List<double> point(Object? value, String field) {
      if (value is! List ||
          value.length != 2 ||
          value.any((v) => v is! num || !v.isFinite)) {
        throw FormatException('نقطهٔ $field معتبر نیست');
      }
      final x = (value[0] as num).toDouble(), y = (value[1] as num).toDouble();
      if (x < 0 || x > width || y < 0 || y > height) {
        throw FormatException('نقطهٔ $field بیرون ابعاد عکس اصلی است');
      }
      return [x, y];
    }

    List<List<double>> polygon(Object? value, String field) {
      if (value is! List || value.length < 3 || value.length > 1024) {
        throw FormatException('چندضلعی $field باید ۳ تا ۱۰۲۴ نقطه داشته باشد');
      }
      return [for (final p in value) point(p, field)];
    }

    final segmentation = object(root['segmentation'], 'segmentation');
    final landmarks = object(root['landmarks_px'], 'landmarks_px');
    final anchors = <String, Object?>{};
    for (final key in [
      'shoulder_image_left',
      'shoulder_image_right',
      'hem_center',
    ]) {
      anchors[key] = point(landmarks[key], key);
    }
    final l = anchors['shoulder_image_left'] as List<double>;
    final r = anchors['shoulder_image_right'] as List<double>;
    final h = anchors['hem_center'] as List<double>;
    if (((r[0] - l[0]) * (h[1] - l[1]) - (r[1] - l[1]) * (h[0] - l[0])).abs() <
        1) {
      throw const FormatException(
        'نقاط شانه و پایین لباس نباید روی یک خط باشند',
      );
    }
    final holes = <List<List<double>>>[];
    final subtract = segmentation['subtract_polygons_px'];
    if (subtract != null) {
      final map = object(subtract, 'subtract_polygons_px');
      if (map.length > 16)
        throw const FormatException('تعداد حفره‌های لباس بیش از حد مجاز است');
      for (final entry in map.entries) {
        holes.add(polygon(entry.value, entry.key));
      }
    }
    final regions = root['regions'] == null
        ? <String, dynamic>{}
        : object(root['regions'], 'regions');
    final sleeves = <Map<String, Object?>>[];
    for (final side in ['left', 'right']) {
      final value = regions['sleeve_image_$side'];
      if (value == null) continue;
      final region = object(value, 'sleeve_image_$side');
      final cuffEdge = region['cuff_edge_px'];
      List<double> hem;
      if (cuffEdge != null) {
        if (cuffEdge is! List || cuffEdge.length != 2) {
          throw FormatException(
            'لبهٔ سرآستین $side باید دقیقاً دو نقطه داشته باشد',
          );
        }
        final a = point(cuffEdge[0], '$side.cuff_edge_px[0]');
        final b = point(cuffEdge[1], '$side.cuff_edge_px[1]');
        final dx = b[0] - a[0], dy = b[1] - a[1];
        if (dx * dx + dy * dy < 1) {
          throw FormatException('دو گوشهٔ سرآستین $side باید از هم جدا باشند');
        }
        // The observed opening is authoritative; an old generated tip must not
        // rotate and shorten the sleeve by being mistaken for its centre.
        hem = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
      } else {
        hem = point(
          landmarks['${side}_sleeve_hem_center'],
          '${side}_sleeve_hem_center',
        );
      }
      sleeves.add({
        'side': side,
        'polygon': polygon(region['polygon_px'], 'sleeve_image_$side'),
        'shoulder': anchors['shoulder_image_$side'],
        'armpit': point(landmarks['${side}_armpit'], '${side}_armpit'),
        'hem': hem,
      });
    }
    final rendering = root['rendering'] == null
        ? <String, dynamic>{}
        : object(root['rendering'], 'rendering');
    return GarmentRenderMetadata._({
      'schema': schema,
      'width': width,
      'height': height,
      'outer': polygon(segmentation['outer_contour_px'], 'outer_contour_px'),
      'holes': holes,
      'anchors': anchors,
      'sleeves': sleeves,
      if (regions['torso'] != null)
        'torso': polygon(
          object(regions['torso'], 'torso')['polygon_px'],
          'torso',
        ),
      'mirrorTexture':
          rendering['mirror_texture_only_if_front_camera_is_mirrored'] == true,
    });
  }
}
