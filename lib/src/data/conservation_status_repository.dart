import 'package:sqflite/sqflite.dart';

class ConservationStatusRepository {
  const ConservationStatusRepository._();

  static Future<String?> loadIucnStatus(
    Database db,
    int speciesId,
  ) async {
    final normalized = await db.query(
      'species_conservation_status',
      columns: const ['status'],
      where: 'species_id=? AND system=? AND scope=? AND jurisdiction_code=?',
      whereArgs: [speciesId, 'iucn_red_list', 'global', ''],
      limit: 1,
    );
    if (normalized.isNotEmpty) {
      final value = normalized.single['status'] as String?;
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }

    final legacy = await db.query(
      'species',
      columns: const ['conservation_status'],
      where: 'id=?',
      whereArgs: [speciesId],
      limit: 1,
    );
    if (legacy.isEmpty) return null;
    final value = legacy.single['conservation_status'] as String?;
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
