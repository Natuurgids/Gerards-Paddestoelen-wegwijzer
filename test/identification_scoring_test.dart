import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/identification_scoring.dart';

void main() {
  group('combineIdentificationScores', () {
    test('keeps morphology dominant when morphology is present', () {
      final result = combineIdentificationScores(
        morphologyScore: 1.0,
        fieldScore: 0.0,
        hasMorphology: true,
      );
      expect(result.combinedScore, closeTo(0.8, 0.0001));
    });

    test('uses field score directly when morphology is absent', () {
      final result = combineIdentificationScores(
        morphologyScore: 0.0,
        fieldScore: 0.75,
        hasMorphology: false,
      );
      expect(result.combinedScore, closeTo(0.75, 0.0001));
    });

    test('clamps malformed input scores', () {
      final result = combineIdentificationScores(
        morphologyScore: 2.0,
        fieldScore: -1.0,
        hasMorphology: true,
      );
      expect(result.morphologyScore, 1.0);
      expect(result.fieldScore, 0.0);
      expect(result.combinedScore, closeTo(0.8, 0.0001));
    });
  });

  group('measurementMatchScore', () {
    test('matches inclusive range boundaries', () {
      expect(measurementMatchScore(observedValue: 5, minValue: 5, maxValue: 15), 1);
      expect(measurementMatchScore(observedValue: 15, minValue: 5, maxValue: 15), 1);
    });

    test('tapers linearly just outside a biological reference range', () {
      expect(
        measurementMatchScore(observedValue: 4, minValue: 5, maxValue: 15),
        closeTo(0.6, 0.0001),
      );
      expect(
        measurementMatchScore(observedValue: 16, minValue: 5, maxValue: 15),
        closeTo(0.6, 0.0001),
      );
    });

    test('reaches zero after a quarter-range shoulder', () {
      expect(measurementMatchScore(observedValue: 2.5, minValue: 5, maxValue: 15), 0);
      expect(measurementMatchScore(observedValue: 17.5, minValue: 5, maxValue: 15), 0);
    });

    test('rejects malformed or zero-width ranges outside the exact value', () {
      expect(measurementMatchScore(observedValue: 10, minValue: 15, maxValue: 5), 0);
      expect(measurementMatchScore(observedValue: 5, minValue: 5, maxValue: 5), 1);
      expect(measurementMatchScore(observedValue: 5.1, minValue: 5, maxValue: 5), 0);
    });
  });

  group('seasonLikelihoodScore', () {
    test('requires exact month and region provenance', () {
      expect(
        seasonLikelihoodScore(
          observationMonth: 9,
          requestedRegionCode: 'GB-IE',
          month: 9,
          dataRegionCode: 'GB-IE',
          likelihood: 3,
        ),
        1,
      );
      expect(
        seasonLikelihoodScore(
          observationMonth: 9,
          requestedRegionCode: 'NL',
          month: 9,
          dataRegionCode: 'GB-IE',
          likelihood: 3,
        ),
        0,
      );
    });

    test('normalizes likelihood to a zero-to-one score', () {
      expect(
        seasonLikelihoodScore(
          observationMonth: 8,
          requestedRegionCode: 'GB-IE',
          month: 8,
          dataRegionCode: 'GB-IE',
          likelihood: 2,
        ),
        closeTo(2 / 3, 0.0001),
      );
    });
  });
}
