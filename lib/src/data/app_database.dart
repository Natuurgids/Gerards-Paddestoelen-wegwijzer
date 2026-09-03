import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'database_seeder.dart';
import 'image_manifest_importer.dart';
import 'species_catalog_importer.dart';
import 'trait_manifest_importer.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'mycology.sqlite');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
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
      },
      onOpen: (db) async {
        await SpeciesCatalogImporter.sync(db);
        await TraitManifestImporter.sync(db);
        await ImageManifestImporter.sync(db);
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
    '''CREATE INDEX idx_species_image_gallery ON species_image(species_id, sort_order)''',
    '''CREATE INDEX idx_question_lesson ON question(lesson_id, sort_order)''',
    '''CREATE INDEX idx_answer_question ON answer_option(question_id, sort_order)''',
  ];
}
