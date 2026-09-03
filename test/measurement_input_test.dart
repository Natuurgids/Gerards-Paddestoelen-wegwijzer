import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/measurement_input.dart';

void main() {
  test('blank measurement is valid optional input', () {
    final result = parseMeasurementInput('   ');
    expect(result.status, MeasurementInputStatus.empty);
    expect(result.isValid, isTrue);
    expect(result.value, isNull);
  });

  test('accepts decimal point and comma', () {
    expect(parseMeasurementInput('12.5').value, closeTo(12.5, 0.0001));
    expect(parseMeasurementInput('12,5').value, closeTo(12.5, 0.0001));
  });

  test('rejects malformed numbers', () {
    final result = parseMeasurementInput('twelve');
    expect(result.status, MeasurementInputStatus.invalidNumber);
    expect(result.isValid, isFalse);
  });

  test('rejects zero and negative measurements', () {
    expect(
      parseMeasurementInput('0').status,
      MeasurementInputStatus.nonPositive,
    );
    expect(
      parseMeasurementInput('-2.5').status,
      MeasurementInputStatus.nonPositive,
    );
  });

  test('rejects non-finite numeric input', () {
    final result = parseMeasurementInput('NaN');
    expect(result.status, MeasurementInputStatus.invalidNumber);
    expect(result.isValid, isFalse);
  });
}
