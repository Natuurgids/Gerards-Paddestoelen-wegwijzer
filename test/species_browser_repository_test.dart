import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/species_browser_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('species browser returns stable pages and filtered results', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseSchema.create(db);

    for (var id = 1; id <= 5; id++) {
      await db.insert('taxon', {
        'id': id,
        'rank': 'species',
        'scientific_name': 'Genus species$id',
      });
      await db.insert('species', {
        'id': id,
        'taxon_id': id,
        'edible_status': 'unknown',
        'toxicity_level': 'unknown',
      });
      await db.insert('species_text', {
        'species_id': id,
        'language_code': 'en',
        'common_name': 'Species $id',
      });
    }

    final repository = SpeciesBrowserRepository(databaseProvider: () async => db);

    final first = await repository.searchPage('en', limit: 2);
    final second = await repository.searchPage('en', offset: 2, limit: 2);
    final filtered = await repository.searchPage('en', query: 'species4');

    expect(first.map((item) => item.id), [1, 2]);
    expect(second.map((item) => item.id), [3, 4]);
    expect(filtered.map((item) => item.id), [4]);
  });
}
