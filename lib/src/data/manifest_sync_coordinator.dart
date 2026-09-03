import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

typedef ManifestSyncStep = Future<void> Function(Database db);

class ManifestSyncCoordinator {
  const ManifestSyncCoordinator._();

  static Future<List<String>> run(
    Database db,
    List<({String name, ManifestSyncStep sync})> steps,
  ) async {
    final failures = <String>[];
    for (final step in steps) {
      try {
        await step.sync(db);
      } catch (error, stackTrace) {
        failures.add(step.name);
        debugPrint('Manifest sync failed for ${step.name}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    return failures;
  }
}
