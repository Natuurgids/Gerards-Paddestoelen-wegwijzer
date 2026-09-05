class PublicObservationCell {
  const PublicObservationCell._({
    required this.speciesId,
    required this.gridCell,
    required this.cellSizeMeters,
    required this.observedYear,
    required this.sourceId,
    required this.sourceRetrievedAt,
    this.sourceRecordId,
  });

  /// Minimum public spatial resolution accepted by the app.
  ///
  /// The app may generalize source data further, but this boundary deliberately
  /// has no latitude/longitude fields and must never be used to reconstruct a
  /// more precise location than the source released publicly.
  static const minimumCellSizeMeters = 1000;

  final int speciesId;
  final String gridCell;
  final int cellSizeMeters;
  final int observedYear;
  final String sourceId;
  final String sourceRetrievedAt;
  final String? sourceRecordId;

  factory PublicObservationCell.publicData({
    required int speciesId,
    required String gridCell,
    required int cellSizeMeters,
    required int observedYear,
    required String sourceId,
    required String sourceRetrievedAt,
    String? sourceRecordId,
  }) {
    final normalizedCell = gridCell.trim();
    final normalizedSourceId = sourceId.trim();
    final normalizedRetrievedAt = sourceRetrievedAt.trim();
    final normalizedRecordId = sourceRecordId?.trim();

    if (speciesId <= 0) {
      throw ArgumentError.value(speciesId, 'speciesId', 'must be positive');
    }
    if (normalizedCell.isEmpty) {
      throw ArgumentError.value(gridCell, 'gridCell', 'must not be empty');
    }
    if (cellSizeMeters < minimumCellSizeMeters) {
      throw ArgumentError.value(
        cellSizeMeters,
        'cellSizeMeters',
        'public observation cells must be at least 1 km',
      );
    }
    if (observedYear < 1000 || observedYear > 9999) {
      throw ArgumentError.value(
        observedYear,
        'observedYear',
        'must be a four-digit year',
      );
    }
    if (normalizedSourceId.isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must not be empty');
    }
    if (!_isIsoDate(normalizedRetrievedAt)) {
      throw ArgumentError.value(
        sourceRetrievedAt,
        'sourceRetrievedAt',
        'must be an ISO date (YYYY-MM-DD)',
      );
    }

    return PublicObservationCell._(
      speciesId: speciesId,
      gridCell: normalizedCell,
      cellSizeMeters: cellSizeMeters,
      observedYear: observedYear,
      sourceId: normalizedSourceId,
      sourceRetrievedAt: normalizedRetrievedAt,
      sourceRecordId:
          normalizedRecordId == null || normalizedRecordId.isEmpty
              ? null
              : normalizedRecordId,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'species_id': speciesId,
        'grid_cell': gridCell,
        'cell_size_m': cellSizeMeters,
        'observed_year': observedYear,
        'source_id': sourceId,
        'source_retrieved_at': sourceRetrievedAt,
        'source_record_id': sourceRecordId,
      };

  static bool _isIsoDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    final canonical =
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    return canonical == value;
  }
}
