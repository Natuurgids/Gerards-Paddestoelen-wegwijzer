import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/public_observation_cell.dart';

void main() {
  test('accepts a source-generalized public observation cell', () {
    final cell = PublicObservationCell.publicData(
      speciesId: 42,
      gridCell: 'NL-123-456',
      cellSizeMeters: 5000,
      observedYear: 2026,
      sourceId: 'ndff-open-data',
      sourceRetrievedAt: '2026-09-05',
    );

    expect(cell.cellSizeMeters, 5000);
    expect(cell.observedYear, 2026);
    expect(cell.sourceId, 'ndff-open-data');
    expect(cell.sourceRetrievedAt, '2026-09-05');
  });

  test('rejects public locations more precise than one kilometre', () {
    expect(
      () => PublicObservationCell.publicData(
        speciesId: 42,
        gridCell: 'precise-cell',
        cellSizeMeters: 999,
        observedYear: 2026,
        sourceId: 'ndff-open-data',
        sourceRetrievedAt: '2026-09-05',
      ),
      throwsArgumentError,
    );
  });

  test('requires source provenance and consultation date', () {
    expect(
      () => PublicObservationCell.publicData(
        speciesId: 42,
        gridCell: 'NL-123-456',
        cellSizeMeters: 1000,
        observedYear: 2026,
        sourceId: ' ',
        sourceRetrievedAt: '2026-09-05',
      ),
      throwsArgumentError,
    );
    expect(
      () => PublicObservationCell.publicData(
        speciesId: 42,
        gridCell: 'NL-123-456',
        cellSizeMeters: 1000,
        observedYear: 2026,
        sourceId: 'ndff-open-data',
        sourceRetrievedAt: '05-09-2026',
      ),
      throwsArgumentError,
    );
  });

  test('storage representation is a strict non-correlating allowlist', () {
    final stored = PublicObservationCell.publicData(
      speciesId: 42,
      gridCell: 'NL-123-456',
      cellSizeMeters: 1000,
      observedYear: 2026,
      sourceId: 'ndff-open-data',
      sourceRetrievedAt: '2026-09-05',
    ).toStorageMap();

    expect(
      stored.keys.toSet(),
      <String>{
        'species_id',
        'grid_cell',
        'cell_size_m',
        'observed_year',
        'source_id',
        'source_retrieved_at',
      },
    );

    const forbiddenFragments = <String>[
      'lat',
      'lon',
      'coordinate',
      'timestamp',
      'observed_at',
      'record_id',
      'observation_id',
      'upload',
      'route',
      'observer',
      'identity',
      'related',
    ];
    for (final key in stored.keys) {
      expect(
        forbiddenFragments.any(key.contains),
        isFalse,
        reason: 'public observation storage leaked correlating key: $key',
      );
    }
  });
}
