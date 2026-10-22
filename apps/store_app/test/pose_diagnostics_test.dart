import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/application/live_tryon_bridge.dart';
import 'package:store_app/domain/pose_diagnostics.dart';
import 'package:store_app/presentation/tryon_debug_overlay.dart';

void main() {
  test(
    'debug points use the same unclamped centre crop as native placement',
    () {
      final (x, y) = posePointInViewport(.05, .5, 640, 480, 360, 640);
      expect(x, closeTo(-204, .001));
      expect(y, closeTo(320, .001));
    },
  );

  test('missing, invalid and stale diagnostics cannot draw a fresh body', () {
    for (final age in [null, -1, 701, double.nan]) {
      expect(PoseDebugSnapshot.fromMap({'resultAgeMs': age}).fresh, isFalse);
    }
    expect(PoseDebugSnapshot.fromMap({'resultAgeMs': 700}).fresh, isTrue);
    final rejected = PoseDebugSnapshot.fromMap({
      'resultAgeMs': 40,
      'reason': 'low_confidence',
      'points': [
        {'x': .3, 'y': .4, 'visibility': .2, 'presence': .9},
        {'x': double.nan, 'y': .4},
      ],
    });
    expect(rejected.points.first.valid, isTrue);
    expect(rejected.points.first.confident, isFalse);
    expect(rejected.points.last.valid, isFalse);
    expect(rejected.text('reason'), 'low_confidence');
  });

  test('placement retains rotation and accepts legacy events', () {
    expect(
      LivePlacement.fromMap({'rotationDegrees': 23.5}).rotationDegrees,
      23.5,
    );
    expect(LivePlacement.fromMap({}).rotationDegrees, 0);
  });

  testWidgets('debug panel fits a small phone and ghost switch works', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    bool ghost = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TryonDebugOverlay(
            snapshot: PoseDebugSnapshot.fromMap({
              'reason': 'low_confidence',
              'resultAgeMs': 10,
            }),
            placement: null,
            garment: 'لباس آزمایشی',
            stage: 'انتظار بدن',
            ghost: false,
            onGhostChanged: (value) => ghost = value,
          ),
        ),
      ),
    );
    expect(
      find.textContaining('اطمینان شانه یا لگن پایین است'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(ghost, isTrue);
    expect(tester.takeException(), isNull);
  });
}
