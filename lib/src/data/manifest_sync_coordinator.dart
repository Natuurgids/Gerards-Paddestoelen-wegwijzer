import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

typedef ManifestSyncStep = Future<void> Function(Database db);
typedef ManifestSyncTask = ({
  String name,
  ManifestSyncStep sync,
  List<String> dependsOn,
});

class ManifestSyncCoordinator {
  const ManifestSyncCoordinator._();

  static Future<List<String>> run(
    Database db,
    List<ManifestSyncTask> steps,
  ) async {
    final unavailable = <String>{};
    final knownSteps = <String>{};

    for (final step in steps) {
      final missingDependencies = step.dependsOn
          .where((dependency) => !knownSteps.contains(dependency))
          .toList();
      if (missingDependencies.isNotEmpty) {
        unavailable.add(step.name);
        debugPrint(
          'Manifest sync skipped for ${step.name}: unknown dependencies '
          '${missingDependencies.join(', ')}',
        );
        knownSteps.add(step.name);
        continue;
      }

      final failedDependencies = step.dependsOn
          .where((dependency) => unavailable.contains(dependency))
          .toList();
      if (failedDependencies.isNotEmpty) {
        unavailable.add(step.name);
        debugPrint(
          'Manifest sync skipped for ${step.name}: unavailable dependencies '
          '${failedDependencies.join(', ')}',
        );
        knownSteps.add(step.name);
        continue;
      }

      try {
        await step.sync(db);
      } catch (error, stackTrace) {
        unavailable.add(step.name);
        debugPrint('Manifest sync failed for ${step.name}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      knownSteps.add(step.name);
    }
    return unavailable.toList();
  }
}
