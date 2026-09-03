class IdentificationScoreBreakdown {
  const IdentificationScoreBreakdown({
    required this.combinedScore,
    required this.morphologyScore,
    required this.fieldScore,
  });

  final double combinedScore;
  final double morphologyScore;
  final double fieldScore;
}

IdentificationScoreBreakdown combineIdentificationScores({
  required double morphologyScore,
  required double fieldScore,
  required bool hasMorphology,
}) {
  final safeMorphology = morphologyScore.clamp(0.0, 1.0).toDouble();
  final safeField = fieldScore.clamp(0.0, 1.0).toDouble();
  final combined = hasMorphology
      ? (safeMorphology * 0.8) + (safeField * 0.2)
      : safeField;
  return IdentificationScoreBreakdown(
    combinedScore: combined,
    morphologyScore: safeMorphology,
    fieldScore: safeField,
  );
}

double measurementMatchScore({
  required double? observedValue,
  required double? minValue,
  required double? maxValue,
}) {
  if (observedValue == null || minValue == null || maxValue == null) return 0;
  if (minValue > maxValue) return 0;
  return observedValue >= minValue && observedValue <= maxValue ? 1 : 0;
}

double seasonLikelihoodScore({
  required int? observationMonth,
  required String? requestedRegionCode,
  required int? month,
  required String? dataRegionCode,
  required int? likelihood,
}) {
  if (observationMonth == null || requestedRegionCode == null) return 0;
  if (month != observationMonth || dataRegionCode != requestedRegionCode) return 0;
  if (likelihood == null || likelihood < 1 || likelihood > 3) return 0;
  return likelihood / 3.0;
}
