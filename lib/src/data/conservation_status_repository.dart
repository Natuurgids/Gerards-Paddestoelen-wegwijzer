import 'package:sqflite/sqflite.dart';

class ConservationStatusRecord {
  const ConservationStatusRecord({
    required this.system,
    required this.scope,
    required this.jurisdictionCode,
    required this.status,
    this.sourceId,
    this.sourceRecordId,
  });

  final String system;
  final String scope;
  final String jurisdictionCode;
  final String status;
  final String? sourceId;
  final String? sourceRecordId;

  bool get isGlobalIucn =>
      system == 'iucn_red_list' && scope == 'global' && jurisdictionCode.isEmpty;

  bool get isDutchRedList =>
      system == 'nl_red_list' && scope == 'national' && jurisdictionCode == 'NL';
}

class ConservationStatusRepository {
  const ConservationStatusRepository._();

  static Future<List<ConservationStatusRecord>> loadStatuses(
    Database db,
    int speciesId,
  ) async {
    final rows = await db.query(
      'species_conservation_status',
      columns: const [
        'system',
        'scope',
        'jurisdiction_code',
        'status',
        'source_id',
        'source_record_id',
      ],
      where: 'species_id=?',
      whereArgs: [speciesId],
      orderBy: 'system, scope, jurisdiction_code',
    );

    final normalized = <ConservationStatusRecord>[];
    for (final row in rows) {
      final system = (row['system'] as String?)?.trim() ?? '';
      final scope = (row['scope'] as String?)?.trim() ?? '';
      final jurisdiction = (row['jurisdiction_code'] as String?)?.trim() ?? '';
      final status = (row['status'] as String?)?.trim() ?? '';
      if (system.isEmpty || scope.isEmpty || status.isEmpty) continue;
      normalized.add(
        ConservationStatusRecord(
          system: system,
          scope: scope,
          jurisdictionCode: jurisdiction,
          status: status,
          sourceId: row['source_id'] as String?,
          sourceRecordId: row['source_record_id'] as String?,
        ),
      );
    }

    if (normalized.any((record) => record.isGlobalIucn)) {
      return normalized;
    }

    final legacy = await db.query(
      'species',
      columns: const ['conservation_status'],
      where: 'id=?',
      whereArgs: [speciesId],
      limit: 1,
    );
    if (legacy.isEmpty) return normalized;
    final legacyStatus = (legacy.single['conservation_status'] as String?)?.trim();
    if (legacyStatus == null || legacyStatus.isEmpty) return normalized;

    return [
      ...normalized,
      ConservationStatusRecord(
        system: 'iucn_red_list',
        scope: 'global',
        jurisdictionCode: '',
        status: legacyStatus,
      ),
    ];
  }

  static Future<String?> loadIucnStatus(
    Database db,
    int speciesId,
  ) async {
    final statuses = await loadStatuses(db, speciesId);
    for (final record in statuses) {
      if (record.isGlobalIucn) return record.status;
    }
    return null;
  }
}
