import 'dart:math' as math;

/// A small symmetric scan correction near the inner edges. The outer
/// page, top and bottom remain fixed.
class ReaderSpreadAlignment {
  const ReaderSpreadAlignment({
    required this.scale,
    required this.offset,
    required this.confidence,
  });

  final double scale;
  final double offset;
  final double confidence;

  static double _smooth(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double strength(double x, {bool rightPage = false}) =>
      _smooth(((rightPage ? 1 - x : x) - .65) / .35);

  double sourceY(double x, double y, {bool rightPage = false}) {
    final inner = strength(x, rightPage: rightPage);
    final ends = _smooth(math.min(y, 1 - y) / .10);
    final delta = ((scale - 1) * y + offset) / (scale + 1);
    return (y + delta * (rightPage ? -1 : 1) * inner * ends).clamp(0.0, 1.0);
  }
}

/// Matches small vertical edge profiles, not full decoded pages. This runs only
/// for a spread explicitly selected by the reader and rejects flat/unrelated
/// edges instead of forcing every pair into a continuous picture.
ReaderSpreadAlignment? findReaderSpreadAlignment(List<List<double>> edges) {
  if (edges.length != 2 || edges[0].length != edges[1].length) return null;
  final length = edges[0].length;
  if (length < 64 || edges.expand((e) => e).any((v) => !v.isFinite)) {
    return null;
  }

  List<double>? normalize(List<double> values) {
    final smooth = List<double>.generate(length, (i) {
      var sum = 0.0;
      var count = 0;
      for (var j = math.max(0, i - 2); j <= math.min(length - 1, i + 2); j++) {
        sum += values[j];
        count++;
      }
      return sum / count;
    });
    final mean = smooth.reduce((a, b) => a + b) / length;
    final variance =
        smooth.fold<double>(0, (sum, v) => sum + (v - mean) * (v - mean)) /
        length;
    if (variance < 64) return null;
    final deviation = math.sqrt(variance);
    return [for (final v in smooth) (v - mean) / deviation];
  }

  final left = normalize(edges[0]);
  final right = normalize(edges[1]);
  if (left == null || right == null) return null;

  double score(double scale, double offset) {
    var sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0;
    var count = 0;
    for (var j = (length * .10).ceil(); j < length * .90; j++) {
      final position = scale * j + offset * (length - 1);
      final low = position.floor();
      if (low < 0 || low + 1 >= length) continue;
      final fraction = position - low;
      final x = left[low] * (1 - fraction) + left[low + 1] * fraction;
      final y = right[j];
      sx += x;
      sy += y;
      sxx += x * x;
      syy += y * y;
      sxy += x * y;
      count++;
    }
    final denominator = math.sqrt(
      math.max(0, (count * sxx - sx * sx) * (count * syy - sy * sy)),
    );
    return denominator <= 1e-8 ? 0 : (count * sxy - sx * sy) / denominator;
  }

  final baseline = score(1, 0);
  if (baseline < .60) return null;
  var bestScore = baseline;
  var bestObjective = baseline;
  var bestScale = 1.0;
  var bestOffset = 0.0;
  for (var s = -15; s <= 15; s++) {
    final scale = 1 + s * .002;
    for (var t = -20; t <= 20; t++) {
      final offset = t * .001;
      if (math.max(offset.abs(), (scale - 1 + offset).abs()) > .03) continue;
      final correlation = score(scale, offset);
      final objective =
          correlation - (scale - 1).abs() * .5 - offset.abs() * .5;
      if (objective > bestObjective) {
        bestObjective = objective;
        bestScore = correlation;
        bestScale = scale;
        bestOffset = offset;
      }
    }
  }
  if (bestScore < .78 || bestScore - baseline < .025) return null;
  return ReaderSpreadAlignment(
    scale: bestScale,
    offset: bestOffset,
    confidence: bestScore,
  );
}
