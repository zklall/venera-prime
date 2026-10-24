import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/utils/reader_spread_alignment.dart';

List<double> profile() => List.generate(512, (i) {
  final x = i / 511;
  var value = 70.0;
  for (final centre in [.14, .24, .39, .55, .71, .85]) {
    value += 100 * math.exp(-math.pow((x - centre) / .012, 2));
  }
  return value + 20 * math.sin(x * 37);
});

double sample(List<double> values, double position) {
  final p = (position * (values.length - 1)).clamp(0.0, values.length - 1.0);
  final i = p.floor(), j = math.min(i + 1, values.length - 1);
  return values[i] * (1 - (p - i)) + values[j] * (p - i);
}

void main() {
  test('finds small scan stretch and offset from continuous artwork', () {
    final left = profile();
    final right = List.generate(
      512,
      (i) => sample(left, 1.024 * i / 511 - .008),
    );
    final alignment = findReaderSpreadAlignment([left, right]);
    expect(alignment, isNotNull);
    expect(alignment!.scale, closeTo(1.024, .004));
    expect(alignment.offset, closeTo(-.008, .003));
    expect(alignment.confidence, greaterThan(.95));
  });

  test('rejects blank margins, unrelated pages and invalid profiles', () {
    final random = math.Random(19);
    expect(
      findReaderSpreadAlignment([List.filled(512, 255), List.filled(512, 255)]),
      isNull,
    );
    expect(
      findReaderSpreadAlignment([
        List.generate(512, (_) => random.nextDouble() * 255),
        List.generate(512, (_) => random.nextDouble() * 255),
      ]),
      isNull,
    );
    expect(
      findReaderSpreadAlignment([
        profile(),
        [double.nan],
      ]),
      isNull,
    );
    expect(
      findReaderSpreadAlignment([
        List.filled(64, double.infinity),
        List.filled(64, 1),
      ]),
      isNull,
    );
  });

  test('already aligned pages do not acquire a correction', () {
    final values = profile();
    expect(findReaderSpreadAlignment([values, values]), isNull);
  });

  test('correction preserves page edges and outer artwork without folding', () {
    const alignment = ReaderSpreadAlignment(
      scale: 1.03,
      offset: -.009,
      confidence: .9,
    );
    var previous = -1.0;
    for (var i = 0; i <= 1000; i++) {
      final y = i / 1000;
      expect(alignment.sourceY(0, y), y);
      expect(alignment.sourceY(.65, y), y);
      final corrected = alignment.sourceY(1, y);
      expect(corrected, inInclusiveRange(0.0, 1.0));
      expect(corrected, greaterThan(previous));
      expect((corrected - y).abs(), lessThanOrEqualTo(.03));
      previous = corrected;
    }
    expect(alignment.sourceY(1, 0), 0);
    expect(alignment.sourceY(1, 1), 1);
    expect(alignment.sourceY(1, .5, rightPage: true), .5);
    final left = alignment.sourceY(1, .5);
    final right = alignment.sourceY(0, .5, rightPage: true);
    expect(left, closeTo(alignment.scale * right + alignment.offset, 1e-10));
  });
}
