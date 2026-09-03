import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'database_seeder.dart';
import 'field_data_importer.dart';
import 'image_manifest_importer.dart';
import 'species_catalog_importer.dart';
import 'training_manifest_importer.dart';
import 'trait_manifest_importer.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _db;
  Future<Database>? _opening;

  Future<Database> get database {
    final existing = _db;
    if (existing != null) return Future.value(existing);
    return _opening ??= _open().then((db) {
      _db = db;
      return db;
    }).whenComplete(() {
      _opening = null;
    });
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'mycology.sqlite');
    return openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA busy_timeout = 5000');
      },
      onCreate: (db, version) async {
        await db.transaction((txn) async {
          for (final statement in _schema) {
            await txn.execute(statement);
          }
          await DatabaseSeeder.seed(txn);
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''CREATE TABLE IF NOT EXISTS trait_text (
            trait_id INTEGER NOT NULL REFERENCES trait(id) ON DELETE CASCADE,
            language_code TEXT NOT NULL CHECK(language_code IN ('nl','en','de')),
            label TEXT NOT NULL,
            help_text TEXT,
            PRIMARY KEY(trait_id, language_code)
          )''');
        }
        if (oldVersion < 3) {
          await db.execute('''CREATE TABLE IF NOT EXISTS species_measurement (
            species_id INTEGER NOT NULL REFERENCES species(id) ON DELETE CASCADE,
            measurement_code TEXT NOT NULL,
            min_value REAL,
            max_value REAL,
            unit TEXT NOT NULL,
            PRIMARY KEY(species_id, measurement_code)
          )''');
          await db.execute('''CREATE TABLE IF NOT EXISTS species_season (
            species_id INTEGER NOT NULL REFERENCES species(id) ON DELETE CASCADE,
            month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12),
            likelihood INTEGER NOT NULL DEFAULT 1 CHECK(likelihood BETWEEN 1 AND 3),
            region_code TEXT,
            PRIMARY KEY(species_id, month)
          )''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_species_measurement_lookup ON species_measurement(measurement_code, min_value, max_value, species_id)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_species_season_month ON species_season(month, likelihood, species_id)');
        }
        if (oldVersion >= 3 && oldVersion < 4) {
          await db.execute('ALTER TABLE species_season ADD COLUMN region_code TEXT');
        }
        if (oldVersion < 5) {
          await db.transaction((txn) async {
            await txn.execute('''CREATE TABLE species_season_v5 (
              species_id INTEGER NOT NULL REFERENCES species(id) ON DELETE CASCADE,
              region_code TEXT NOT NULL,
              month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12),
              likelihood INTEGER NOT NULL DEFAULT 1 CHECK(likelihood BETWEEN 1 AND 3),
              PRIMARY KEY(species_id, region_code, month)
            )''');
            await txn.execute('''INSERT OR IGNORE INTO species_season_v5(species_id, region_code, month, likelihood)
              SELECT species_id, COALESCE(region_code, 'UNSPECIFIED'), month, likelihood FROM species_season''');
            await txn.execute('DROP TABLE species_season');
            await txn.execute('ALTER TABLE species_season_v5 RENAME TO species_season');
            await txn.execute('CREATE INDEX idx_species_season_region_month ON species_season(region_code, month, likelihood, species_id)');
          });
        }
      },
      onOpen: (db) async {
        await SpeciesCatalogImporter.sync(db);
        await TraitManifestImporter.sync(db);
        await FieldDataImporter.sync(db);
        await ImageManifestImporter.sync(db);
        await TrainingManifestImporter.sync(db);
      },
    );
  }

  static const _schema = <String>[
    '''CREATE TABLE taxon (
      id INTEGER PRIMARY KEY,
      parent_id INTEGER REFERENCES taxon(id),
      rank TEXT NOT NULL CHECK(rank IN ('kingdom','phylum','class','order','family','genus','species')),
      scientific_name TEXT NOT NULL,
      author_citation TEXT,
      UNIQUE(rank, scientific_name)
    )''',
    '''CREATE TABLE species (
      id INTEGER PRIMARY KEY,
      taxon_id INTEGER NOT NULL UNIQUE REFERENCES taxon(id) ON DELETE CASCADE,
      edible_status TEXT NOT NULL DEFAULT 'unknown',
      toxicity_level TEXT NOT NULL DEFAULT 'unknown',
      conservation_status TEXT,
      notes_key TEXT
    )''',
    '''CREATE TABLE species_text (
      species_id INTEGER NOT NULL REFERENCES species(id) ON DELETE CASCADE,
      language_code TEXT NOT NULL CHECK(language_code IN ('nl','en','de')),
      common_name TEXT NOT NULL,
      summary TEXT,
      description TEXT,
      habitat_text TEXT,
      lookalikes_text TEXT,
      PRIMARY KEY(species_id, language_code)
    )''',
    '''CREATE TABLE trait (
      id INTEGER PRIMARY KEY,
      code TEXT NOT NULL UNIQUE,
      category TEXT NOT NULL,
      value_type TEXT NOT NULL CHECK(value_type IN ('choice','boolean','number','text'))
    )''',
    '''CREATE TABLE trait_text (
      trait_id INTEGER NOT NULL REFERENCES trait(id) ON DELETE CASCADE,
      language_code TEXT NOT NULL CHECK(language_code IN ('nl','en','de')),
      label TEXT NOT NULL,
      help_text TEXT,
      PRIMARY KEY(trait_id, language_code)
    )''',
    '''CREATE TABLE trait_option (
      id INTEGER PRIMARY KEY,
      trait_id INTEGER NOT NULL REFERENCES trait(id) ON DELETE CASCADE,
      code TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      UNIQUE(trait_id, code)
    )''',
    '''CREATE TABLE trait_option_text (
      option_id INTEGER NOT NULL REFERENCES trait_option(id) ON DELETE CASCADE,
      language_code TEXT NOT NULL CHECK(language_code IN ('nl','en','de')),
      label TEXT NOT NULL,
      PRIMARY KEY(option_id, language_code)
    )''',
    '''CREATE TABLE species_trait (
      species_id INTEGER NOT NULL REFERENCES species(id) ON DELETE CASCADE,
      trait_id INTEGER NOT NULL REFERENCES trait(id) ON DELETE CASCADE,
      option_id INTEGER REFERENCES trait_option(id) ON DELETE CASCADE,
      numeric_min REAL,
      numeric_max REAL,
      text_value TEXT,
      weight REAL NOT NULL DEFAULT 1.0,
      PRIMARY KEY(species_id, trait_id, option_id)
    )''',
    '''CREATE TABLE species_measurement (
      species_id INTEGER NOT NULL REFERENCES species(id) ON DELETE CASCADE,
      measurement_code TEXT NOT NULL,
      min_value REAL,
      max_value REAL,
      unit TEXT NOT NULL,
      PRIMARY KEY(species_id, measurement_code)
    )''',
    '''CREATE TABLE species_season (
      species_id INTEGER NOT NULL REFERENCES species(id) ON DELETE CASCADE,
      region_code TEXT NOT NULL,
      month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12),
      likelihood INTEGER NOT NULL DEFAULT 1 CHECK(likelihood BETWEEN 1 AND 3),
      PRIMARY KEY(species_id, region_code, month)
    )''',
    '''CREATE TABLE species_image (
      id INTEGER PRIMARY KEY,
      species_id INTEGER NOT NULL REFERENCES species(id) ON DELETE CASCADE,
      asset_path TEXT NOT NULL,
      thumbnail_path TEXT,
      angle_code TEXT,
      caption_key TEXT,
      photographer TEXT,
      license TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_primary INTEGER NOT NULL DEFAULT 0 CHECK(is_primary IN (0,1)),
      UNIQUE(species_id, asset_path)
    )''',
    '''CREATE TABLE lesson (
      id INTEGER PRIMARY KEY,
      slug TEXT NOT NULL UNIQUE,
      difficulty INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE lesson_text (
      lesson_id INTEGER NOT NULL REFERENCES lesson(id) ON DELETE CASCADE,
      language_code TEXT NOT NULL CHECK(language_code IN ('nl','en','de')),
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      PRIMARY KEY(lesson_id, language_code)
    )''',
    '''CREATE TABLE question (
      id INTEGER PRIMARY KEY,
      lesson_id INTEGER REFERENCES lesson(id) ON DELETE SET NULL,
      species_id INTEGER REFERENCES species(id) ON DELETE SET NULL,
      question_type TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE question_text (
      question_id INTEGER NOT NULL REFERENCES question(id) ON DELETE CASCADE,
      language_code TEXT NOT NULL CHECK(language_code IN ('nl','en','de')),
      prompt TEXT NOT NULL,
      explanation TEXT,
      PRIMARY KEY(question_id, language_code)
    )''',
    '''CREATE TABLE answer_option (
      id INTEGER PRIMARY KEY,
      question_id INTEGER NOT NULL REFERENCES question(id) ON DELETE CASCADE,
      is_correct INTEGER NOT NULL CHECK(is_correct IN (0,1)),
      sort_order INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE answer_option_text (
      answer_id INTEGER NOT NULL REFERENCES answer_option(id) ON DELETE CASCADE,
      language_code TEXT NOT NULL CHECK(language_code IN ('nl','en','de')),
      label TEXT NOT NULL,
      PRIMARY KEY(answer_id, language_code)
    )''',
    '''CREATE TABLE training_progress (
      lesson_id INTEGER NOT NULL REFERENCES lesson(id) ON DELETE CASCADE,
      completed_at TEXT,
      best_score REAL NOT NULL DEFAULT 0,
      attempts INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(lesson_id)
    )''',
    '''CREATE INDEX idx_taxon_parent ON taxon(parent_id)''',
    '''CREATE INDEX idx_taxon_scientific_name ON taxon(scientific_name COLLATE NOCASE)''',
    '''CREATE INDEX idx_species_text_language_name ON species_text(language_code, common_name COLLATE NOCASE)''',
    '''CREATE INDEX idx_trait_text_language_label ON trait_text(language_code, label COLLATE NOCASE)''',
    '''CREATE INDEX idx_species_trait_filter ON species_trait(trait_id, option_id, species_id)''',
    '''CREATE INDEX idx_species_measurement_lookup ON species_measurement(measurement_code, min_value, max_value, species_id)''',
    '''CREATE INDEX idx_species_season_region_month ON species_season(region_code, month, likelihood, species_id)''',
    '''CREATE INDEX idx_species_image_gallery ON species_image(species_id, sort_order)''',
    '''CREATE INDEX idx_question_lesson ON question(lesson_id, sort_order)''',
    '''CREATE INDEX idx_answer_question ON answer_option(question_id, sort_order)''',
  ];
}
