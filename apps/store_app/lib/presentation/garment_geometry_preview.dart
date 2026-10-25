import 'dart:io';
import 'package:flutter/material.dart';
import '../domain/garment_model_metadata.dart';
import '../domain/garment_render_metadata.dart';

/// Display the exact, untrimmed source coordinate canvas before live fitting.
class GarmentGeometryPreview extends StatelessWidget {
  const GarmentGeometryPreview({
    super.key,
    required this.photoPath,
    required this.controller,
  });
  final String photoPath;
  final TextEditingController controller;

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      Map<String, Object?>? geometry;
      try {
        final metadata = GarmentModelMetadata.isModel(value.text)
            ? GarmentModelMetadata.parse(value.text).photoMetadata()
            : GarmentRenderMetadata.parse(value.text);
        geometry = metadata?.toNativeMap();
      } on FormatException {
        return const SizedBox.shrink();
      }
      if (geometry == null) return const SizedBox.shrink();
      final data = geometry;
      return ExpansionTile(
        title: const Text('بررسی مرزها روی عکس اصلی'),
        subtitle: const Text('سبز: لباس، قرمز: حفرهٔ یقه، زرد: آستین'),
        children: [
          AspectRatio(
            aspectRatio: (data['width'] as num) / (data['height'] as num),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(photoPath),
                  fit: BoxFit.fill,
                  errorBuilder: (_, error, stack) =>
                      const Center(child: Text('عکس اصلی در دسترس نیست')),
                ),
                IgnorePointer(
                  child: CustomPaint(painter: _GeometryPainter(data)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'اگر خط‌ها روی مرز واقعی لباس نیستند، هندسه را با همان عکس اصلاح کنید. عکس صاف و نور پراکنده، با نوردهی و تراز سفیدی مشابه محل پرو استفاده شود.',
            ),
          ),
        ],
      );
    },
  );
}

class _GeometryPainter extends CustomPainter {
  _GeometryPainter(this.geometry);
  final Map<String, Object?> geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / (geometry['width'] as num);
    final sy = size.height / (geometry['height'] as num);
    Offset point(Object? value) {
      final p = value as List;
      return Offset((p[0] as num) * sx, (p[1] as num) * sy);
    }

    void polygon(Object? value, Color color) {
      final points = value as List;
      if (points.isEmpty) return;
      final path = Path()..addPolygon(points.map(point).toList(), true);
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    polygon(geometry['outer'], Colors.greenAccent);
    for (final hole in geometry['holes'] as List) {
      polygon(hole, Colors.redAccent);
    }
    for (final sleeve in geometry['sleeves'] as List) {
      polygon((sleeve as Map)['polygon'], Colors.amber);
    }
    for (final anchor in (geometry['anchors'] as Map).values) {
      canvas.drawCircle(point(anchor), 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_GeometryPainter oldDelegate) =>
      oldDelegate.geometry != geometry;
}
