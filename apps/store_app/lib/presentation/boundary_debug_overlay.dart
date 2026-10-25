import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/pose_diagnostics.dart';

class BoundaryDebugOverlay extends StatelessWidget {
  const BoundaryDebugOverlay({
    super.key,
    required this.snapshot,
    required this.ghost,
    required this.onGhostChanged,
  });
  final PoseDebugSnapshot? snapshot;
  final bool ghost;
  final ValueChanged<bool> onGhostChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final lines = snapshot?.boundaryLines ?? const <BoundaryDebugLine>[];
      final anatomical = lines
          .where((line) => line.evidence == 'estimated')
          .map((line) => line.kind)
          .toSet();
      final labels = {
        'arm_11': 'اتصال بازوی ۱۱',
        'arm_12': 'اتصال بازوی ۱۲',
        'neck': 'پایهٔ گردن',
        'hips': 'مرز لگن',
      };
      final status = lines.isEmpty
          ? 'منتظر بدن معتبر؛ خطوط قدیمی نمایش داده نمی‌شوند'
          : labels.entries
                .where((entry) => anatomical.contains(entry.key))
                .map((entry) => entry.value)
                .join(' · ');
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _BoundaryPainter(snapshot, lines)),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: math.min(225, constraints.maxHeight * .38),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xdf10131a),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'مرز بدن و خم لباس',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Text(
                          'لباس شفاف',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        Switch(value: ghost, onChanged: onGhostChanged),
                      ],
                    ),
                    const Text(
                      'فیروزه‌ای خط‌چین: اتصال بازو، گردن و لگن؛ تخمین از مفاصل',
                      style: TextStyle(color: Colors.cyanAccent, fontSize: 11),
                    ),
                    const Text(
                      'فیروزه‌ای پیوسته: بخش‌های دیده‌شدهٔ مرز ماسک',
                      style: TextStyle(color: Colors.cyanAccent, fontSize: 11),
                    ),
                    const Text(
                      'نارنجی: آغاز خم به پشت در پهلو، دو لبهٔ آستین و بالای شانه',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                      ),
                    ),
                    const Text(
                      'صورتی: یقهٔ رندرشده · سفید: دور لباس · پایین لباس خم نمی‌شود',
                      style: TextStyle(color: Colors.pinkAccent, fontSize: 11),
                    ),
                    Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    if (lines.isNotEmpty &&
                        !lines.any((line) => line.kind.endsWith('_roll')))
                      const Text(
                        'خط خم برای این لباس در دسترس نیست؛ هندسهٔ عکس لباس لازم است.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    Text(
                      'پایداری تنه: ${snapshot?.number('bodyFitScale').toStringAsFixed(2) ?? '—'} · حرکت آستین: ${snapshot?.number('deformationScale').toStringAsFixed(2) ?? '—'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const Text(
                      'ماسک فعلی مرز داخلی گردن و زیر بغل را جداگانه تشخیص نمی‌دهد؛ محل دقیق این اتصال‌ها هنوز قابل تأیید نیست.',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _BoundaryPainter extends CustomPainter {
  _BoundaryPainter(this.snapshot, this.lines);
  final PoseDebugSnapshot? snapshot;
  final List<BoundaryDebugLine> lines;
  @override
  void paint(Canvas canvas, Size size) {
    final d = snapshot;
    if (d == null || lines.isEmpty) return;
    Offset position((double, double) point) {
      final (x, y) = posePointInViewport(
        point.$1,
        point.$2,
        d.number('imageWidth'),
        d.number('imageHeight'),
        size.width,
        size.height,
      );
      return Offset(x, y);
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final line in lines) {
      final points = line.points.map(position).toList();
      final estimated = line.evidence == 'estimated';
      final color = line.evidence == 'mask' || estimated
          ? Colors.cyanAccent
          : line.kind == 'neckline'
          ? Colors.pinkAccent
          : line.kind == 'garment_outline'
          ? Colors.white70
          : Colors.orangeAccent;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final paint = Paint()
        ..color = color
        ..strokeWidth = line.kind == 'garment_outline' ? 1 : 2.5
        ..style = PaintingStyle.stroke;
      if (estimated) {
        for (final metric in path.computeMetrics()) {
          for (double distance = 0; distance < metric.length; distance += 11) {
            canvas.drawPath(
              metric.extractPath(
                distance,
                math.min(distance + 7, metric.length),
              ),
              paint,
            );
          }
        }
      } else {
        canvas.drawPath(path, paint);
      }
      if (estimated) {
        for (final p in [points.first, points.last]) {
          canvas.drawCircle(p, 3, Paint()..color = color);
        }
        const labels = {
          'arm_11': 'بازو ۱۱',
          'arm_12': 'بازو ۱۲',
          'neck': 'گردن',
          'hips': 'لگن',
        };
        final text = TextPainter(
          text: TextSpan(
            text: labels[line.kind] ?? '',
            style: TextStyle(
              color: color,
              fontSize: 11,
              backgroundColor: Colors.black87,
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        final center = (points.first + points.last) * .5;
        text.paint(canvas, center + const Offset(4, -15));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoundaryPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot;
}
