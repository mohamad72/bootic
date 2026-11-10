import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/presentation/stage_debug_overlay.dart';
import 'package:store_app/presentation/tryon_debug_overlay.dart';
import 'package:store_app/domain/pose_diagnostics.dart';

void main() {
  testWidgets('stage buttons switch views and keep source failure explicit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var stage = DebugStage.source;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => StageDebugOverlay(
              stage: stage,
              onStageChanged: (value) => setState(() => stage = value),
              garmentName: 'لباس آزمایشی',
              photoPath: null,
              geometry: null,
              snapshot: null,
              ghost: false,
              onGhostChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('عکس اصلی'), findsOneWidget);
    await tester.tap(find.text('۲. بدن'));
    await tester.pump();
    expect(stage, DebugStage.body);
    expect(find.textContaining('بدون خروجی تازه'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.text('۳. قرارگیری'));
    await tester.pump();
    expect(stage, DebugStage.placement);
    expect(find.byType(Switch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('stalled stream removes live body guides', (tester) async {
    final frame = PoseDebugSnapshot.fromMap({
      'reason': 'accepted',
      'resultAgeMs': 0,
      'imageWidth': 400,
      'imageHeight': 600,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StageDebugOverlay(
            stage: DebugStage.body,
            onStageChanged: (_) {},
            garmentName: 'test',
            photoPath: null,
            geometry: null,
            snapshot: frame,
            ghost: false,
            onGhostChanged: (_) {},
          ),
        ),
      ),
    );
    Finder guides() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is PoseDebugPainter,
    );
    expect(guides(), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 850)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(guides(), findsNothing);
    expect(find.textContaining('بدون خروجی تازه'), findsOneWidget);
  });
}
