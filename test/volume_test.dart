import 'package:flutter_test/flutter_test.dart';
import 'package:gymprogress/models.dart';

void main() {
  test('volumen de una serie = reps × peso', () {
    expect(const SetData(10, 30, 90).volume, 300);
  });
  test('volumen total con series de peso y reps distintos', () {
    final s = [const SetData(12, 20, 60), const SetData(10, 30, 90), const SetData(8, 40, 90), const SetData(6, 45, 120)];
    expect(totalVolume(s), 240 + 300 + 320 + 270);
  });
  test('peso cero es válido y negativos se descartan', () {
    expect(const SetData(15, 0, 60).isValid, true);
    expect(const SetData(10, -5, 60).isValid, false);
    expect(totalVolume([const SetData(10, -5, 0), const SetData(10, 10, 0)]), 100);
  });
}
