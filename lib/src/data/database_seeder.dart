import 'package:sqflite/sqflite.dart';

/// Creates no developer-managed content.
///
/// Catalogue, identification, field, gallery and training content are loaded
/// exclusively from the bundled manifests during [AppDatabase.onOpen]. Keeping
/// this hook empty avoids a second source of truth while preserving the schema
/// creation call site for older migrations and future non-content bootstrap
/// needs.
class DatabaseSeeder {
  static Future<void> seed(Transaction txn) async {}
}
