import 'dart:async';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import 'core_dataset_package.dart';
import 'core_dataset_transport.dart';

const coreDatasetManifestUrl = String.fromEnvironment(
  'CORE_DATASET_MANIFEST_URL',
);

enum CoreDatasetUpdateAttemptOutcome {
  notConfigured,
  upToDate,
  incompatibleSchema,
  updated,
  unavailable,
  rejected,
}

class CoreDatasetUpdateAttempt {
  const CoreDatasetUpdateAttempt({
    required this.outcome,
    required this.installedVersion,
    this.latestVersion,
  });

  final CoreDatasetUpdateAttemptOutcome outcome;
  final int installedVersion;
  final int? latestVersion;
}

class CoreDatasetUpdateService {
  const CoreDatasetUpdateService({
    required this.manifestUrl,
    this.byteSource = const HttpCoreDatasetByteSource(),
  });

  final String manifestUrl;
  final CoreDatasetByteSource byteSource;

  Future<CoreDatasetUpdateAttempt> checkAndApply(Database db) async {
    final installed = await CoreDatasetInstalledState.load(db);
    final configuredUrl = manifestUrl.trim();
    if (configuredUrl.isEmpty) {
      return CoreDatasetUpdateAttempt(
        outcome: CoreDatasetUpdateAttemptOutcome.notConfigured,
        installedVersion: installed.datasetVersion,
      );
    }

    CoreDatasetUpdateResult result;
    try {
      final manifestUri = Uri.parse(configuredUrl);
      final source = RemoteCoreDatasetUpdateSource(
        manifestUri: manifestUri,
        byteSource: byteSource,
      );
      result = await CoreDatasetUpdater(
        manifestSource: source,
        byteSource: byteSource,
      ).checkAndApply(db);
    } on IOException {
      return CoreDatasetUpdateAttempt(
        outcome: CoreDatasetUpdateAttemptOutcome.unavailable,
        installedVersion: installed.datasetVersion,
      );
    } on TimeoutException {
      return CoreDatasetUpdateAttempt(
        outcome: CoreDatasetUpdateAttemptOutcome.unavailable,
        installedVersion: installed.datasetVersion,
      );
    } on FormatException {
      return CoreDatasetUpdateAttempt(
        outcome: CoreDatasetUpdateAttemptOutcome.rejected,
        installedVersion: installed.datasetVersion,
      );
    } on StateError {
      return CoreDatasetUpdateAttempt(
        outcome: CoreDatasetUpdateAttemptOutcome.rejected,
        installedVersion: installed.datasetVersion,
      );
    }

    return CoreDatasetUpdateAttempt(
      outcome: switch (result.outcome) {
        CoreDatasetUpdateOutcome.upToDate =>
          CoreDatasetUpdateAttemptOutcome.upToDate,
        CoreDatasetUpdateOutcome.incompatibleSchema =>
          CoreDatasetUpdateAttemptOutcome.incompatibleSchema,
        CoreDatasetUpdateOutcome.updated => CoreDatasetUpdateAttemptOutcome.updated,
      },
      installedVersion: result.installedAfter.datasetVersion,
      latestVersion: result.latest.datasetVersion,
    );
  }
}
