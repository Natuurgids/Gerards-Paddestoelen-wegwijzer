class SpeciesSummary {
  const SpeciesSummary({required this.id, required this.scientificName, required this.commonName, required this.summary, required this.imagePath});
  final int id;
  final String scientificName;
  final String commonName;
  final String? summary;
  final String? imagePath;
}

class SpeciesDetail extends SpeciesSummary {
  const SpeciesDetail({required super.id, required super.scientificName, required super.commonName, required super.summary, required super.imagePath, required this.description, required this.habitat, required this.lookalikes, required this.edibleStatus, required this.toxicityLevel, required this.images, required this.measurements, required this.season});
  final String? description;
  final String? habitat;
  final String? lookalikes;
  final String edibleStatus;
  final String toxicityLevel;
  final List<SpeciesImage> images;
  final List<SpeciesMeasurement> measurements;
  final List<SpeciesSeasonMonth> season;
}

class SpeciesImage {
  const SpeciesImage({required this.path, required this.angleCode, required this.sortOrder, this.photographer, this.license});
  final String path;
  final String? angleCode;
  final int sortOrder;
  final String? photographer;
  final String? license;
}

class SpeciesMeasurement {
  const SpeciesMeasurement({required this.code, required this.minValue, required this.maxValue, required this.unit});
  final String code;
  final double? minValue;
  final double? maxValue;
  final String unit;
}

class SpeciesSeasonMonth {
  const SpeciesSeasonMonth({required this.month, required this.likelihood});
  final int month;
  final int likelihood;
}

class TraitChoice {
  const TraitChoice({required this.traitId, required this.traitCode, required this.traitLabel, required this.optionId, required this.optionLabel});
  final int traitId;
  final String traitCode;
  final String traitLabel;
  final int optionId;
  final String optionLabel;
}

class IdentificationCandidate {
  const IdentificationCandidate({required this.species, required this.score, required this.matched, required this.requested});
  final SpeciesSummary species;
  final double score;
  final int matched;
  final int requested;
}

class LessonSummary {
  const LessonSummary({required this.id, required this.title, required this.body, required this.difficulty, required this.bestScore, required this.attempts});
  final int id;
  final String title;
  final String body;
  final int difficulty;
  final double bestScore;
  final int attempts;
}

class QuizQuestion {
  const QuizQuestion({required this.id, required this.prompt, required this.explanation, required this.answers});
  final int id;
  final String prompt;
  final String? explanation;
  final List<QuizAnswer> answers;
}

class QuizAnswer {
  const QuizAnswer({required this.id, required this.label, required this.isCorrect});
  final int id;
  final String label;
  final bool isCorrect;
}
