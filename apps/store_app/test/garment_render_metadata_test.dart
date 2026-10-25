import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/domain/garment_render_metadata.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/striped_tshirt_metadata.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  test(
    'cuff corners determine the opening midpoint instead of a stale outer tip',
    () {
      final data = fixture();
      data['regions']['sleeve_image_left']['cuff_edge_px'] = [
        [0, 441],
        [80, 658],
      ];
      data['landmarks_px']['left_sleeve_hem_center'] = [0, 458];
      final native = GarmentRenderMetadata.parse(
        jsonEncode(data),
      )!.toNativeMap();
      final sleeve = (native['sleeves'] as List).first as Map;
      expect(sleeve['hem'], [40.0, 549.5]);
    },
  );
  test(
    'legacy references without cuff corners retain their saved cuff midpoint',
    () {
      final native = GarmentRenderMetadata.parse(
        jsonEncode(fixture()),
      )!.toNativeMap();
      expect(((native['sleeves'] as List).first as Map)['hem'], [113.0, 567.0]);
    },
  );
  test(
    'invalid optional cuff corners cannot silently fall back to a bad tip',
    () {
      for (final edge in [
        [
          [0, 441],
        ],
        [
          [0, 441],
          [0, 441],
        ],
        [
          [-1, 441],
          [80, 658],
        ],
        [
          [0, '441'],
          [80, 658],
        ],
      ]) {
        final data = fixture();
        data['regions']['sleeve_image_left']['cuff_edge_px'] = edge;
        expect(
          () => GarmentRenderMetadata.parse(jsonEncode(data)),
          throwsFormatException,
        );
      }
    },
  );
}
