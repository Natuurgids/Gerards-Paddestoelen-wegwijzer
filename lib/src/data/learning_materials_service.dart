import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'learning_access.dart';
import 'learning_commerce.dart';
import 'learning_offering.dart';
import 'learning_package.dart';
import 'learning_package_installer.dart';

typedef LearningMaterialsDatabaseProvider = Future<Database> Function();
typedef LearningOfferingCatalogLoader = Future<LearningOfferingCatalog> Function();

class LearningMaterialLocalState {
  const LearningMaterialLocalState({
    required this.offering,
    required this.entitlementGranted,
    required this.installed,
    required this.lessonIds,
  });

  final LearningOffering offering;
  final bool entitlementGranted;
  final InstalledLearningPackageState? installed;
  final Set<int> lessonIds;

  bool get hasInstalledContent => installed != null && lessonIds.isNotEmpty;

  bool get canOpen => entitlementGranted && hasInstalledContent;

  bool get needsOwnershipBackfill => installed != null && lessonIds.isEmpty;
}

class LearningMaterialsLocalSnapshot {
  const LearningMaterialsLocalSnapshot({
    required this.materials,
    required this.purchasesConfigured,
    required this.deliveryConfigured,
  });

  final List<LearningMaterialLocalState> materials;
  final bool purchasesConfigured;
  final bool deliveryConfigured;
}

abstract interface class LearningMaterialsService {
  bool get purchasesConfigured;
  bool get deliveryConfigured;

  Future<LearningMaterialsLocalSnapshot> loadLocal();

  Future<Map<String, LearningProductQuote>> loadProductQuotes(
    Iterable<LearningOffering> offerings,
  );

  Future<void> purchase(String productKey);

  Future<void> restorePurchases();

  Future<Map<String, int>> loadRemoteVersions(
    Iterable<LearningOffering> offerings,
  );

  Future<LearningPackageInstallResult> install(String packageKey);
}

class DefaultLearningMaterialsService implements LearningMaterialsService {
  DefaultLearningMaterialsService({
    required EntitlementRepository entitlements,
    required LearningPackageInstaller installer,
    required LearningMaterialsDatabaseProvider databaseProvider,
    required LearningOfferingCatalogLoader offeringLoader,
    LearningCommerceCoordinator? commerce,
  })  : _entitlements = entitlements,
        _installer = installer,
        _databaseProvider = databaseProvider,
        _offeringLoader = offeringLoader,
        _commerce = commerce;

  factory DefaultLearningMaterialsService.standard() {
    const entitlements = EmptyEntitlementRepository();
    return DefaultLearningMaterialsService(
      entitlements: entitlements,
      installer: const LearningPackageInstaller(
        catalogUrl: learningPackageCatalogUrl,
        entitlements: entitlements,
      ),
      databaseProvider: () => AppDatabase.instance.database,
      offeringLoader: LearningOfferingCatalog.loadBundled,
    );
  }

  final EntitlementRepository _entitlements;
  final LearningPackageInstaller _installer;
  final LearningMaterialsDatabaseProvider _databaseProvider;
  final LearningOfferingCatalogLoader _offeringLoader;
  final LearningCommerceCoordinator? _commerce;

  @override
  bool get purchasesConfigured => _commerce?.configured ?? false;

  @override
  bool get deliveryConfigured => _installer.catalogUrl.trim().isNotEmpty;

  @override
  Future<LearningMaterialsLocalSnapshot> loadLocal() async {
    final catalog = await _offeringLoader();
    _validateCommerceCatalog(catalog.offerings);
    final entitlements = await _entitlements.loadEntitlements();
    final db = await _databaseProvider();
    final materials = <LearningMaterialLocalState>[];

    for (final offering in catalog.offerings) {
      final installed = await InstalledLearningPackageState.load(
        db,
        offering.packageKey,
      );
      final lessonIds = await LearningPackageLessonOwnership.lessonIdsForPackage(
        db,
        offering.packageKey,
      );
      materials.add(
        LearningMaterialLocalState(
          offering: offering,
          entitlementGranted: entitlements.grants(offering.entitlementKey),
          installed: installed,
          lessonIds: Set.unmodifiable(lessonIds),
        ),
      );
    }

    return LearningMaterialsLocalSnapshot(
      materials: List.unmodifiable(materials),
      purchasesConfigured: purchasesConfigured,
      deliveryConfigured: deliveryConfigured,
    );
  }

  @override
  Future<Map<String, LearningProductQuote>> loadProductQuotes(
    Iterable<LearningOffering> offerings,
  ) async {
    final commerce = _commerce;
    if (commerce == null || !commerce.configured) {
      return const <String, LearningProductQuote>{};
    }
    _validateCommerceCatalog(offerings);
    return commerce.loadQuotes();
  }

  @override
  Future<void> purchase(String productKey) async {
    final commerce = _commerce;
    if (commerce == null || !commerce.configured) {
      throw StateError('Learning commerce is not configured');
    }
    await commerce.purchase(productKey);
  }

  @override
  Future<void> restorePurchases() async {
    final commerce = _commerce;
    if (commerce == null || !commerce.configured) {
      throw StateError('Learning commerce is not configured');
    }
    await commerce.restorePurchases();
  }

  @override
  Future<Map<String, int>> loadRemoteVersions(
    Iterable<LearningOffering> offerings,
  ) async {
    final remote = await _installer.loadCatalog();
    if (remote == null) return const <String, int>{};

    final offeringsByPackage = {
      for (final offering in offerings) offering.packageKey: offering,
    };
    final versions = <String, int>{};
    for (final descriptor in remote.packages) {
      final offering = offeringsByPackage[descriptor.packageKey];
      if (offering == null) continue;
      _validateRemoteIdentity(offering, descriptor);
      versions[descriptor.packageKey] = descriptor.contentVersion;
    }
    return Map.unmodifiable(versions);
  }

  @override
  Future<LearningPackageInstallResult> install(String packageKey) async {
    final db = await _databaseProvider();
    return _installer.install(db, packageKey);
  }

  void _validateCommerceCatalog(Iterable<LearningOffering> offerings) {
    final commerce = _commerce;
    if (commerce == null) return;
    final expected = LearningCommerceCatalog.fromOfferings(offerings);
    if (expected.productKeys.length != commerce.catalog.productKeys.length ||
        !expected.productKeys.containsAll(commerce.catalog.productKeys)) {
      throw StateError(
        'Learning commerce catalog does not match bundled learning offerings',
      );
    }
    for (final productKey in expected.productKeys) {
      final expectedBinding = expected.bindingForProduct(productKey)!;
      final actualBinding = commerce.catalog.bindingForProduct(productKey);
      if (actualBinding == null ||
          actualBinding.entitlementKey != expectedBinding.entitlementKey) {
        throw StateError(
          'Learning commerce binding does not match bundled learning offering: '
          '$productKey',
        );
      }
    }
  }
}

void _validateRemoteIdentity(
  LearningOffering offering,
  LearningPackageDescriptor descriptor,
) {
  if (offering.courseKey != descriptor.courseKey ||
      offering.entitlementKey != descriptor.entitlementKey ||
      offering.productKey != descriptor.productKey) {
    throw FormatException(
      'Remote learning package identity does not match bundled offering '
      '${offering.packageKey}',
    );
  }
}
