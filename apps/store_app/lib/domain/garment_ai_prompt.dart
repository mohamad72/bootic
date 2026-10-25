import 'dart:convert';
import 'field_definition.dart';
import 'garment.dart';
import 'garment_ai_import.dart';
import 'garment_render_metadata.dart';

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
    const json = JsonEncoder.withIndent('  ');
    return '''You are Bootic Photo Garment and Catalog Extractor v3.
Analyze the ONE attached garment photograph. Return ONE JSON object only, matching OUTPUT TEMPLATE below. No prose, markdown, code fences, image generation, URLs or executable code.

WORKFLOW AND REFERENCE
The operator will paste your response into Bootic to fill the catalog form AND supply live try-on geometry. The original photograph is the texture: do not generate a replacement image, crop it, trim its canvas, erase its background, mirror it or change its framing. The app masks ONLY from your polygons during rendering.
Echo photo_id EXACTLY. Use the supplied coordinate_canvas dimensions in try_on.source. If the attached photograph is the same uncropped image at another resolution, map all coordinates proportionally onto coordinate_canvas. If it is a different photo, cropped, or contains multiple garments, ask for a correct single reference instead of fabricating usable geometry.

CATALOG RULES
- Use Persian for descriptive text, but use EXACT machine keys for category and audience from the contract. null means unknown and preserves existing manual information. Do not convert unknown numbers to zero.
- Give a short visible description as name. Fill metadata using ONLY enabled metadata_fields keys, declared types and exact listed option strings. No new fields or enum options. Describe visible pattern/color/style honestly; exact fabric composition requires a readable label or operator information.
- Metadata types: text is a string up to 500 characters; longText up to 4000; integer is an integer; decimal a finite number; boolean true/false; singleSelect one exact listed option; multiSelect an array of exact listed options (at most 100); date ISO Gregorian YYYY-MM-DD; year an integer 1900..2200; yearRange [minYear,maxYear] in that range; numberRange [min,max]; color #RRGGBB; score a number 0..1; tags an array of at most 20 nonempty strings (at most 80 characters each). Use null for unknown, not empty strings or placeholders.
- audience is a garment product category (men, women, girls, boys, unisex). Use explicit product information, a readable label or the operator's choice; when unclear use null. Do not infer the sex/gender/age of a person wearing the garment. Never use unisex as an unknown default.
- price and discountPrice are WHOLE TOMAN amounts; stock is a whole nonnegative count. These, collection, sku, barcode, isActive and physical measurements are null unless explicitly supplied by the operator or clearly readable on the relevant label. Never estimate price, inventory or centimetres/millimetres from appearance. measurements_mm.chest is garment chest WIDTH, not circumference; length is garment length, both in millimetres. No physical measurement without supplied calibration/verified data.
- Retain the operator_supplied_values. Do not replace known values with visual guesses. Unknown metadata values are null, including optional required fields that cannot be established; the operator will complete these in the form.

GEOMETRY RULES
1. Preserve the source pixels and canvas. Pixel origin is top-left; x increases right, y increases down. ALL points use coordinate_canvas, must be finite and inside its bounds. Image-left/right are NOT anatomical left/right. Never mirror the source landmarks.
2. Trace outer_contour_px clockwise around ONLY the garment. Use 3..1024 vertices, with more near neck/cuffs/armpits/hem; avoid self intersections and degenerate shapes. Do not include floor, hanger, hands, skin or background.
3. subtract_polygons_px is an object of named removal polygons (3..1024 points each, at most 16). Subtract internal empty regions. For front-view shirts, also remove the visible REAR panel, tag and back neck binding inside the neck opening, keeping the real FRONT collar band. Preserve graphics, logos, stripes, seams, cuffs, buttons and all real front-facing garment texture. Use {} when there are no holes.
4. Source shoulder_image_left and shoulder_image_right are the upper shoulder seam/sleeve-root attachment points on the garment, not rectangle corners or armpits. hem_center is the middle of the torso's lower hem, not the middle of the photograph. These three anchors must not be collinear.
5. Annotate torso and each VISIBLE sleeve separately with polygon_px. Sleeve polygons touch the torso at their actual shoulder-to-armpit seam. Supply left_armpit/right_armpit and left_sleeve_hem_center/right_sleeve_hem_center for the respective sleeve. Sleeve hem_center is the centre of its CUFF opening, not its outermost tip. The renderer uses these exact keys.
6. Omit a nonexistent/hidden optional sleeve region and its optional landmarks instead of inventing points. Do not put [0,0] placeholders in actual output. For sleeveless garments omit both sleeve regions. Required outer contour and shoulder/hem anchors must be genuine observations. If these cannot be established, request a clearer front photo instead of inventing geometry.
7. The current renderer attaches torso to shoulders/hips and sleeves towards elbows with a 2D mesh. Do not claim exact 3D drape, true size fit, unseen back/side reconstruction, or foreground occlusion. Do not add unsupported instructions or pretend they execute. Geometry is approximate, to be verified in live debug.
8. Validate coordinates, anchors, polygons, field types and option values before answering. No alpha bitmap/base64/RLE arrays. Return the complete object, not a patch or a string containing JSON.

PHOTO QUALITY
Keep exact product colors, prints, front collar and sleeve edges. Do not synthesize cylinders, a parametric model, new folds, shadows or unseen back surfaces. A flat, evenly lit reference is preferred: source shadows and folds remain in its texture. Trace the FRONT neck opening, excluding visible back-neck panel/tag but preserving front collar trim. Sleeve shoulder-to-armpit boundaries must meet the torso exactly, without gaps or overlap.

CURRENT CONTRACT
${json.convert(contract)}

OUTPUT TEMPLATE (replace all placeholder coordinates and fill observed values; keep unknown catalog values null)
${json.convert(template)}
''';
  }
}
