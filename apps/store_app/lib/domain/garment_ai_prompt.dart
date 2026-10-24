import 'dart:convert';
import 'field_definition.dart';
import 'garment.dart';
import 'garment_ai_import.dart';
import 'garment_render_metadata.dart';
import 'garment_model_metadata.dart';

/// A manual copy/paste workflow. No API keys, network calls or image uploads.
class GarmentAiPrompt {
  static String build({
    required String photoId,
    required int width,
    required int height,
    required List<FieldDefinition> fields,
    Map<String, Object?> knownValues = const {},
  }) {
    final enabled = fields.where((f) => f.enabled).toList();
    final contract = {
      'photo_id': photoId,
      'coordinate_canvas': {'width_px': width, 'height_px': height},
      'allowed_categories': garmentCategories,
      'allowed_audiences': garmentAudiences,
      'metadata_fields': enabled.map((f) => f.toJson()).toList(),
      'operator_supplied_values': knownValues,
    };
    final template = {
      'schema_version': GarmentAiImport.schema,
      'photo_id': photoId,
      'garment': {
        'name': null,
        'category': null,
        'audience': null,
        'collection': null,
        'sku': null,
        'barcode': null,
        'price': null,
        'discountPrice': null,
        'stock': null,
        'isActive': null,
        'metadata': {for (final field in enabled) field.key: null},
        'measurements_mm': {'chest': null, 'length': null},
      },
      'try_on': {
        'schema_version': GarmentRenderMetadata.schema,
        'source': {
          'image': photoId,
          'width_px': width,
          'height_px': height,
          'coordinate_system':
              'source-image pixels, origin top-left, x-right, y-down',
          'points_convention':
              'image_left/image_right; not anatomical left/right',
          'source_view': 'front',
          'pixel_coordinates_are_approximate': true,
        },
        'segmentation': {
          'outer_contour_px': [
            [0, 0],
            [0, 0],
            [0, 0],
          ],
          'subtract_polygons_px': {},
        },
        'landmarks_px': {
          'shoulder_image_left': [0, 0],
          'shoulder_image_right': [0, 0],
          'hem_center': [0, 0],
          'left_armpit': [0, 0],
          'right_armpit': [0, 0],
          'left_sleeve_hem_center': [0, 0],
          'right_sleeve_hem_center': [0, 0],
        },
        'regions': {
          'torso': {
            'polygon_px': [
              [0, 0],
              [0, 0],
              [0, 0],
            ],
          },
          'sleeve_image_left': {
            'polygon_px': [
              [0, 0],
              [0, 0],
              [0, 0],
            ],
          },
          'sleeve_image_right': {
            'polygon_px': [
              [0, 0],
              [0, 0],
              [0, 0],
            ],
          },
        },
        'rendering': {'mirror_texture_only_if_front_camera_is_mirrored': true},
      },
    };
    final sourceTemplate = template['try_on'];
    template['try_on'] = {
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
        'pattern': 'solid',
        'pattern_scale': 0.05,
        'pattern_duty': 0.25,
        'weave': 'plain',
        'orientation': 'horizontal',
        'roughness': 0.85,
      },
      'source_metadata': null,
    };
    const json = JsonEncoder.withIndent('  ');
    return '''You are Bootic Parametric Garment and Catalog Extractor v2.
Analyze ONE attached garment photo. Return ONE complete JSON object matching OUTPUT TEMPLATE. No markdown, executable code, URLs or base64.

REFERENCE
Echo photo_id exactly. Describe a reusable 3D garment, not the photograph's pose or folds. The app builds and caches a mesh once and animates it with the customer's body. Do not encode this customer's anatomy or a fixed pixel offset. This is approximate visual preview, not certified sizing or physical cloth simulation. The unseen back cannot be verified from one photo.

CATALOG
Use Persian descriptive values, exact category/audience enums and metadata keys/options from CURRENT CONTRACT. Unknown values MUST be null and preserve manual values. NEVER turn missing price/stock into zero. Price/discountPrice are integer TOMAN 0..999999999999; stock integer 0..999999; use only operator-supplied values or relevant readable labels. Do not guess fabric composition, physical millimetres, price, inventory, SKU or audience from a person's body. Keep operator values. Audience is a PRODUCT classification: men/women/girls/boys/unisex; unknown null. name <=120 characters; collection <=500; sku/barcode <=200. isActive boolean or null. measurements_mm chest WIDTH and length require verified calibration or explicit operator data, otherwise null.
Metadata types: text <=500 chars, longText <=4000, integer, finite decimal, boolean, singleSelect exact option, multiSelect exact options <=100, date Gregorian YYYY-MM-DD, year 1900..2200, yearRange [min,max], numberRange [min,max], color #RRGGBB, score 0..1, tags <=20 strings each <=80. Unknown null. No extra fields.

MODEL
kind must match catalog category: top/coat/dress/skirt/trousers. Shape values are bounded visual RATIOS, not real measurements:
- length 0.6..2.2: upper-body garments as shoulder-to-hip ratio; skirt/trousers as hip-to-ankle fraction (normally <=1). Consider intended garment cut, never source canvas margins.
- hem_width 0.65..1.8: hem width relative to garment shoulder width (or hip width for lower garments).
- ease 0..0.25: additional width fraction, use conservative regular fit 0.06 unless visible cut says otherwise.
- sleeve_length 0..1 of shoulder-to-wrist length: 0 sleeveless, around .3 short, .55 elbow, 1 full length. Applies only upper-body garments.
- neck_width 0.12..0.32 of full shoulder width (half neck opening width); neck_depth 0.02..0.3 of torso length. neckline round/v; unsupported collars are approximate, do not promise exact reconstruction.
material colors #RRGGBB approximate diffuse colors without baked lighting. roughness .3..1 controls surface sheen, .85 for matte fabric.
Choose procedural for plain/repeating stripes/checks: pattern solid/stripes/checks; pattern_scale 0.005..0.15 is one FULL repeating period as a fraction of shoulder width; pattern_duty 0.05..0.95 is the fraction occupied by accent_color; orientation horizontal/vertical. Count actual repeat spacing relative to garment width and distinguish narrow dark lines from wider light gaps. weave plain/knit/denim describes visible surface structure approximately, not fiber composition; use plain when unclear. For simple patterns source_metadata MUST be null; no photo pixels are used live.
Choose source for logos, complex prints, embroidery, irregular motifs that cannot be recreated by those patterns. Provide source_metadata using SOURCE GEOMETRY TEMPLATE below. Original photograph texture will be mapped onto a 3D surface. One photo cannot reveal unseen surfaces; do not invent back details. Never erase/trim/mirror the source or generate a replacement image.

SOURCE GEOMETRY (only for source material)
Use coordinate_canvas pixel dimensions exactly, map proportionally if same uncropped photo was resized. If different/cropped/multiple garments ask for a single correct reference. Trace clockwise outer_contour_px around garment only; 3..1024 finite in-bounds points per polygon. subtract_polygons_px <=16 named polygons excludes neck openings/back-neck tag/visible rear panel without deleting front collar. No background/hanger/skin. shoulder_image_left/right are upper shoulder seam roots; hem_center is torso hem middle. Those three must be noncollinear. Annotate torso and each visible sleeve polygon separately; each sleeve needs corresponding armpit and left_sleeve_hem_center/right_sleeve_hem_center at cuff opening centre. Omit nonexistent sleeves and their optional anchors. No [0,0] placeholders. Image-left/right, never anatomical sides. Texture projection is approximate and cannot recover unseen surfaces.
${json.convert(sourceTemplate)}

CURRENT CONTRACT
${json.convert(contract)}

OUTPUT TEMPLATE (replace observed appearance; keep unknown commercial values null)
${json.convert(template)}
''';
  }
}
