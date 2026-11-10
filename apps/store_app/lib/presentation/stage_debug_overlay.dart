import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/pose_diagnostics.dart';
import 'garment_geometry_preview.dart';
import 'tryon_debug_overlay.dart';
import 'boundary_debug_overlay.dart';

enum DebugStage { source, body, placement }

/// Stage controls and evidence drawn from the same data consumed by the renderer.
class StageDebugOverlay extends StatefulWidget {
  const StageDebugOverlay({
    super.key,
    required this.stage,
    required this.onStageChanged,
    required this.garmentName,
    required this.photoPath,
    required this.geometry,
    required this.snapshot,
    required this.ghost,
    required this.onGhostChanged,
  });
  final DebugStage stage;
  final ValueChanged<DebugStage> onStageChanged;
  final String garmentName;
  final String? photoPath;
  final Map<String, Object?>? geometry;
  final PoseDebugSnapshot? snapshot;
  final bool ghost;
  final ValueChanged<bool> onGhostChanged;
  @override
  State<StageDebugOverlay> createState() => _StageDebugOverlayState();
}

class _StageDebugOverlayState extends State<StageDebugOverlay> {
  final _age = Stopwatch()..start();
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(StageDebugOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) _age.reset();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.snapshot;
    final d = original == null
        ? null
        : PoseDebugSnapshot.fromMap({
            ...original.values,
            // A stalled event stream must not leave apparently live lines on screen.
            'resultAgeMs':
                original.number('resultAgeMs') + _age.elapsedMilliseconds,
          });
    final fresh = d != null && d.fresh && d.text('reason') == 'accepted';
    final source = widget.stage == DebugStage.source;
    final body = widget.stage == DebugStage.body;
    final geometry = widget.geometry;
    return Stack(
      children: [
        if (source)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: const Color(0xff10131a),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 170, 12, 130),
                  child: widget.photoPath == null || geometry == null
                      ? const Center(
                          child: Text(
                            'عکس اصلی یا هندسهٔ لباس در دسترس نیست',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : Center(
                          child: AspectRatio(
                            aspectRatio:
                                (geometry['width'] as num) /
                                (geometry['height'] as num),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(widget.photoPath!),
                                  fit: BoxFit.fill,
                                  errorBuilder: (_, error, stack) =>
                                      const Center(
                                        child: Text(
                                          'عکس اصلی در دسترس نیست',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                ),
                                IgnorePointer(
                                  child: CustomPaint(
                                    painter: GarmentGeometryPainter(geometry),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        if (!source && fresh)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: body
                    ? PoseDebugPainter(d, null)
                    : BoundaryDebugPainter(d, d.boundaryLines),
              ),
            ),
          ),
        Positioned(
          top: 66,
          left: 8,
          right: 8,
          child: _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final stage in DebugStage.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ChoiceChip(
                            label: Text(
                              const [
                                '۱. لباس',
                                '۲. بدن',
                                '۳. قرارگیری',
                              ][stage.index],
                            ),
                            selected: widget.stage == stage,
                            onSelected: (_) => widget.onStageChanged(stage),
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  'لباس: ${widget.garmentName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  source
                      ? 'مرحله ۱ · مرز ثبت‌شده، پیش از تغییرشکل'
                      : body
                      ? 'مرحله ۲ · بدن زنده، بدون لباس مجازی'
                      : 'مرحله ۳ · هندسهٔ نهایی لباس روی بدن',
                ),
                if (!source)
                  Text(
                    '${fresh ? 'خروجی تازه' : 'بدون خروجی تازه / بدن معتبر'} · ${d?.number('fps').toStringAsFixed(1) ?? '—'} fps · تأخیر ${d?.number('latencyMs').toStringAsFixed(0) ?? '—'} ms',
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 8,
          right: 8,
          child: _panel(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  source
                      ? 'سبز: مرز برش · قرمز: حفره‌ها · زرد: آستین · سفید: اتصال'
                      : body
                      ? 'صورتی: مرز ماسک · سبز: مفاصل · زرد: اتصال اصلاح‌شده'
                      : 'سفید: دور لباس · صورتی: یقه · نارنجی: راهنمای خم\nفیروزه‌ای پیوسته: ماسک · خط‌چین: اتصال تخمینی',
                ),
                Text(
                  source
                      ? 'اگر مرز با عکس تطبیق ندارد، ایراد از دادهٔ لباس ورودی است.'
                      : body
                      ? 'مرز ماسک شامل لباس فعلی فرد است؛ پوست زیر آن نیست.'
                      : 'اگر دو مرحلهٔ قبل درست‌اند، اتصال و تغییرشکل را اینجا بررسی کنید.',
                ),
                if (widget.stage == DebugStage.placement)
                  Row(
                    children: [
                      const Expanded(child: Text('لباس نیمه‌شفاف')),
                      Switch(
                        value: widget.ghost,
                        onChanged: widget.onGhostChanged,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xee10131a),
      borderRadius: BorderRadius.circular(12),
    ),
    child: DefaultTextStyle(
      style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.5),
      child: Directionality(textDirection: TextDirection.rtl, child: child),
    ),
  );
}
