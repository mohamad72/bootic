import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/domain/pose_diagnostics.dart';
import 'package:store_app/presentation/boundary_debug_overlay.dart';

void main() {
  Map<Object?, Object?> frame() => {
    'reason': 'accepted',
    'resultAgeMs': 10,
    'imageWidth': 400,
    'imageHeight': 600,
    'boundaryLines': [
      {
        'kind': 'neck',
        'evidence': 'estimated',
        'points': [
          [.4, .3],
          [.6, .3],
        ],
      },
      {
        'kind': 'torso_roll',
        'evidence': 'rendered',
        'points': [
          [.3, .4],
          [.3, .7],
        ],
      },
      {
        'kind': 'invalid',
        'evidence': 'mask',
        'points': [
          [double.nan, .2],
          [.5, .4],
        ],
      },
      {
        'kind': 'unknown',
        'evidence': 'guessed-as-real',
        'points': [
          [.2, .2],
          [.4, .4],
        ],
      },
    ],
  };
  test('only valid fresh accepted boundaries can reach the painter', () {
    final snapshot = PoseDebugSnapshot.fromMap(frame());
    expect(snapshot.boundaryLines.map((line) => line.kind), [
      'neck',
      'torso_roll',
    ]);
    expect(snapshot.boundaryLines.first.points.first, (.4, .3));
    for (final change in [
      {'resultAgeMs': 701},
      {'reason': 'low_confidence'},
      {'imageWidth': 0},
      {'imageHeight': -1},
    ]) {
      expect(
        PoseDebugSnapshot.fromMap({...frame(), ...change}).boundaryLines,
        isEmpty,
      );
    }
  });
  testWidgets(
    'boundary mode explains estimates and its ghost control fits a small phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bool ghost = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoundaryDebugOverlay(
              snapshot: PoseDebugSnapshot.fromMap(frame()),
              ghost: false,
              onGhostChanged: (value) => ghost = value,
            ),
          ),
        ),
      );
      expect(find.text('مرز بدن و خم لباس'), findsOneWidget);
      expect(find.textContaining('خط‌چین'), findsOneWidget);
      expect(find.textContaining('نارنجی'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(ghost, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
