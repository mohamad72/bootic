/// Only numerical, in-memory diagnostics. No camera frames or identity data.
class PoseDebugPoint {
  const PoseDebugPoint(this.x, this.y, this.visibility, this.presence);
  final double x, y, visibility, presence;
  bool get valid => x.isFinite && y.isFinite;
  bool get confident => valid && visibility >= 0.5 && presence >= 0.5;
}

class PoseDebugSnapshot {
  PoseDebugSnapshot.fromMap(this.values)
    : points = [
        for (final point in (values['points'] as List? ?? const []))
          if (point is Map)
            PoseDebugPoint(
              (point['x'] as num?)?.toDouble() ?? double.nan,
              (point['y'] as num?)?.toDouble() ?? double.nan,
              (point['visibility'] as num?)?.toDouble() ?? 0,
              (point['presence'] as num?)?.toDouble() ?? 0,
            ),
      ];
  final Map<Object?, Object?> values;
  final List<PoseDebugPoint> points;
  double number(String key) {
    final value = (values[key] as num?)?.toDouble() ?? 0;
    return value.isFinite ? value : 0;
  }

  String text(String key) => values[key]?.toString() ?? '—';
  bool flag(String key) => values[key] == true;
  bool get fresh =>
      values['resultAgeMs'] is num &&
      (values['resultAgeMs'] as num).isFinite &&
      number('resultAgeMs') >= 0 &&
      number('resultAgeMs') <= 700;
}

/// Matches native FILL_CENTER; coordinates intentionally remain unclamped.
(double, double) posePointInViewport(
  double x,
  double y,
  double imageWidth,
  double imageHeight,
  double viewWidth,
  double viewHeight,
) {
  if (imageWidth <= 0 || imageHeight <= 0) return (0, 0);
  final sx = viewWidth / imageWidth;
  final sy = viewHeight / imageHeight;
  final scale = sx > sy ? sx : sy;
  return (
    (viewWidth - imageWidth * scale) / 2 + x * imageWidth * scale,
    (viewHeight - imageHeight * scale) / 2 + y * imageHeight * scale,
  );
}
