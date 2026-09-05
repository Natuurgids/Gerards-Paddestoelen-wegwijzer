class PublicObservationCell {
  const PublicObservationCell._({
    required this.speciesId,
    required this.gridCell,
    required this.cellSizeMeters,
    required this.observedYear,
    required this.sourceId,
    required this.sourceRetrievedAt,
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

  factory PublicObservationCell.publicData({
    required int speciesId,
    required String gridCell,
    required int cellSizeMeters,
    required int observedYear,
    required String sourceId,
    required String sourceRetrievedAt,
    required int sourceMinimumCellSizeMeters,
    required bool sourcePermitsPublicDisplay,
  }) {
    final normalizedCell = gridCell.trim();
    final normalizedSourceId = sourceId.trim();
    final normalizedRetrievedAt = sourceRetrievedAt.trim();

    if (speciesId <= 0) {
      throw ArgumentError.value(speciesId, 'speciesId', 'must be positive');
    }
    if (normalizedCell.isEmpty) {
      throw ArgumentError.value(gridCell, 'gridCell', 'must not be empty');
    }
    if (!sourcePermitsPublicDisplay) {
      throw ArgumentError.value(
        sourcePermitsPublicDisplay,
        'sourcePermitsPublicDisplay',
        'source policy does not permit public display for this observation',
      );
    }
    if (sourceMinimumCellSizeMeters < minimumCellSizeMeters) {
      throw ArgumentError.value(
        sourceMinimumCellSizeMeters,
        'sourceMinimumCellSizeMeters',
        'source public precision must be at least 1 km',
      );
    }
    if (cellSizeMeters < sourceMinimumCellSizeMeters) {
      throw ArgumentError.value(
        cellSizeMeters,
        'cellSizeMeters',
        'public observation cell is more precise than source policy permits',
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
    );
  }

  /// Whitelisted public storage representation.
  ///
  /// Deliberately excludes upstream observation identifiers, upload times,
  /// routes, observer identities, related-record keys, and exact timestamps.
  /// Those fields can correlate generalized records back to sensitive source
  /// observations even when coordinates themselves are absent. Source policy
  /// inputs are validation-only and are not persisted per observation.
  Map<String, Object?> toStorageMap() => {
        'species_id': speciesId,
        'grid_cell': gridCell,
        'cell_size_m': cellSizeMeters,
        'observed_year': observedYear,
        'source_id': sourceId,
        'source_retrieved_at': sourceRetrievedAt,
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
