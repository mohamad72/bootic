import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../application/live_tryon_bridge.dart';
import '../domain/pose_diagnostics.dart';

class TryonDebugOverlay extends StatelessWidget {
  const TryonDebugOverlay({
    super.key,
    required this.snapshot,
    required this.placement,
    required this.garment,
    required this.stage,
    required this.ghost,
    required this.onGhostChanged,
    this.expanded = false,
    this.onToggleDetails,
  });
  final PoseDebugSnapshot? snapshot;
  final LivePlacement? placement;
  final String garment, stage;
  final bool ghost, expanded;
  final VoidCallback? onToggleDetails;
  final ValueChanged<bool> onGhostChanged;

  static const _reasons = {
    'waiting': 'هنوز خروجی مدل نرسیده',
    'accepted': 'بدن پذیرفته شد',
    'no_pose': 'مدل بدن پیدا نکرد',
    'invalid_landmarks': 'مختصات نامعتبر',
    'low_confidence': 'اطمینان شانه یا لگن پایین است',
    'torso_out_of_frame': 'شانه یا لگن بیرون کادر است',
    'shoulder_span': 'فاصلهٔ شانه‌ها نامعتبر است',
    'torso_length': 'طول تنه نامعتبر است',
    'torso_alignment': 'هم‌راستایی تنه نامعتبر است',
    'inference_error': 'ارسال فریم به مدل خطا داد',
    'tracker_error': 'اجرای مدل متوقف شد',
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final d = snapshot;
      String n(String key, [int digits = 0]) =>
          d?.number(key).toStringAsFixed(digits) ?? '—';
      String confidence(int index, String label) {
        if (d == null || d.points.length <= index) return '$label: —';
        final p = d.points[index];
        return '$label: V=${p.visibility.toStringAsFixed(2)} P=${p.presence.toStringAsFixed(2)}';
      }

      final p = placement;
      final lines = [
        'نسخه: ${d?.text('version') ?? '—'} | ${d?.text('revision') ?? 'pose-v4-json'}',
        'تشخیص: ${_reasons[d?.text('reason')] ?? 'در انتظار اطلاعات'}',
        'تازگی: ${d?.fresh == true ? 'تازه' : 'قدیمی / بدون خروجی'} | عمر خروجی: ${n('resultAgeMs')} ms',
        'سرعت خروجی مدل: ${n('fps', 1)} fps | تأخیر: ${n('latencyMs')} ms',
        'پذیرش: ${n('accepted')} | رد: ${n('rejected')} | آخرین بدن معتبر: ${n('poseAgeMs')} ms قبل',
        'تصویر مدل: ${n('imageWidth')}×${n('imageHeight')} px | پیش‌نمایش: ${n('viewWidth')}×${n('viewHeight')} px',
        'عرض شانه: ${n('shoulderPx', 1)} px | طول تنه: ${n('torsoPx', 1)} px',
        'کادر لباس روی صفحه: ${((p?.width ?? 0) * constraints.maxWidth).toStringAsFixed(0)}×${((p?.height ?? 0) * constraints.maxHeight).toStringAsFixed(0)} dp | چرخش: ${(p?.rotationDegrees ?? 0).toStringAsFixed(1)}°',
        'ضریب عرض: ${n('widthFactor', 2)} | طول: ${n('heightFactor', 2)} | حد مدل: ${n('modelConfidence', 2)}',
        'حد نقاط: حضور ≥۰٫۵؛ دید ≥۰٫۳ و حداقل یک شانه و یک لگن با دید ≥۰٫۵',
        confidence(11, 'شانهٔ چپ، نقطهٔ ۱۱'),
        confidence(12, 'شانهٔ راست، نقطهٔ ۱۲'),
        confidence(23, 'لگن چپ، نقطهٔ ۲۳'),
        confidence(24, 'لگن راست، نقطهٔ ۲۴'),
        'دوربین: ${d?.flag('front') == true ? 'جلو' : 'عقب'} | آینه: ${d?.flag('mirror') == true ? 'بله' : 'خیر'}',
        'مرحله: $stage | افکت: ${d?.text('effect') ?? '—'}',
        'علامت دست: ${d?.text('gesture') ?? '—'} | رأی‌گیری: ${d?.flag('voting') == true ? 'فعال' : 'غیرفعال'}',
        'لباس: $garment | عکس: ${n('garmentWidth')}×${n('garmentHeight')} px',
        'راهنما: سبز = نقاط مطمئن؛ قرمز = ضعیف؛ آبی = محدودهٔ نقاط؛ نارنجی = کادر لباس.',
        'رندر لباس: ${d?.text('renderer') ?? '—'}',
        'کادر ورودی مشترک: ${d?.text('frameGeometry') ?? '—'}',
        'توضیح: خطوط، تخمین نقاط بدن هستند، نه لبهٔ دقیق پوست. اندازهٔ سانتی‌متری بدون کالیبراسیون نداریم.',
        'اطمینان: مقدار V احتمال دیده‌شدن نقطه و مقدار P احتمال حضور آن است.',
      ];
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _PoseDebugPainter(d, p)),
            ),
          ),
          Positioned(
            top: 64,
            left: 8,
            right: 8,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: math.min(238, constraints.maxHeight * 0.36),
              ),
              padding: const EdgeInsets.all(8),
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
                            'دیباگ بدن',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Text(
                          'لباس نیمه‌شفاف',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        Switch(value: ghost, onChanged: onGhostChanged),
                        IconButton(
                          tooltip: expanded
                              ? 'جمع کردن جزئیات'
                              : 'نمایش همهٔ جزئیات',
                          onPressed: onToggleDetails,
                          icon: Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                    for (final line
                        in expanded
                            ? lines
                            : [lines[0], lines[1], lines[6], lines[3]])
                      Text(
                        line,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.5,
                        ),
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

class _PoseDebugPainter extends CustomPainter {
  _PoseDebugPainter(this.data, this.placement);
  final PoseDebugSnapshot? data;
  final LivePlacement? placement;
  static const connections = [
    (11, 12),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
    (11, 23),
    (12, 24),
    (23, 24),
    (23, 25),
    (25, 27),
    (24, 26),
    (26, 28),
    (27, 29),
    (29, 31),
    (28, 30),
    (30, 32),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final d = data;
    if (d != null &&
        d.fresh &&
        d.number('imageWidth') > 0 &&
        d.number('imageHeight') > 0) {
      Offset position(PoseDebugPoint p) {
        final (x, y) = posePointInViewport(
          p.x,
          p.y,
          d.number('imageWidth'),
          d.number('imageHeight'),
          size.width,
          size.height,
        );
        return Offset(x, y);
      }

      for (final (a, b) in connections) {
        if (d.points.length <= b || !d.points[a].valid || !d.points[b].valid)
          continue;
        paint.color = d.points[a].confident && d.points[b].confident
            ? Colors.greenAccent
            : Colors.redAccent;
        canvas.drawLine(position(d.points[a]), position(d.points[b]), paint);
      }
      final confident = d.points
          .where((p) => p.confident)
          .map(position)
          .toList();
      if (confident.length >= 2) {
        paint.color = Colors.cyanAccent;
        canvas.drawRect(
          Rect.fromLTRB(
            confident.map((p) => p.dx).reduce(math.min),
            confident.map((p) => p.dy).reduce(math.min),
            confident.map((p) => p.dx).reduce(math.max),
            confident.map((p) => p.dy).reduce(math.max),
          ),
          paint,
        );
      }
      for (var i = 0; i < d.points.length; i++) {
        final p = d.points[i];
        if (!p.valid) continue;
        paint.color = p.confident ? Colors.greenAccent : Colors.redAccent;
        canvas.drawCircle(position(p), 3.5, paint);
        if (const {11, 12, 15, 16, 23, 24, 25, 26, 27, 28}.contains(i)) {
          final text = TextPainter(
            text: TextSpan(
              text: '$i',
              style: TextStyle(
                color: paint.color,
                fontSize: 11,
                backgroundColor: Colors.black87,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(canvas, position(p) + const Offset(4, 0));
        }
      }
    }
    final p = placement;
    if (p != null && p.visible) {
      paint.color = Colors.orangeAccent;
      canvas.save();
      canvas.translate(p.centerX * size.width, p.centerY * size.height);
      canvas.rotate(p.rotationDegrees * math.pi / 180);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.width * size.width,
          height: p.height * size.height,
        ),
        paint,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PoseDebugPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.placement != placement;
}
