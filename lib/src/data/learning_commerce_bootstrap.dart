import 'dart:io';

import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'learning_commerce.dart';
import 'learning_commerce_runtime.dart';
import 'learning_in_app_purchase.dart';
import 'learning_materials_service.dart';
import 'learning_offering.dart';
import 'learning_package_installer.dart';
import 'learning_purchase_verifier_http.dart';
import 'verified_entitlement_cache.dart';

enum LearningCommerceBootstrapStatus {
  configured,
  unsupportedPlatform,
  missingSessionHeadersProvider,
  missingStoreProductIds,
  invalidStoreProductIds,
  incompleteStoreProductIds,
  missingVerifierEndpoints,
  invalidVerifierConfiguration,
}

class LearningCommerceBootstrapResult {
  const LearningCommerceBootstrapResult({
    required this.status,
    required this.service,
    this.runtime,
  });

  final LearningCommerceBootstrapStatus status;
  final LearningMaterialsService service;
  final LearningCommerceRuntime? runtime;

  bool get configured => status == LearningCommerceBootstrapStatus.configured;

  Future<void> close() async {
    await runtime?.close();
  }
}

typedef LearningCommercePlatformProvider = LearningCommerceProvider? Function();

/// Assembles the production learning-commerce dependencies only when every
/// deployment prerequisite is present.
///
/// Endpoint URLs and provider product IDs are public deployment configuration.
/// Authentication/session headers are runtime state and must be supplied by the
/// caller; no reusable verifier secret is read from compile-time configuration.
class LearningCommerceBootstrap {
  const LearningCommerceBootstrap._();

  static Future<LearningCommerceBootstrapResult> fromEnvironment({
    LearningVerifierHeadersProvider? sessionHeadersProvider,
    LearningCommercePlatformProvider? platformProvider,
    LearningOfferingCatalogLoader? offeringLoader,
    LearningMaterialsDatabaseProvider? databaseProvider,
    LearningStoreProductIds? productIds,
    LearningInAppPurchaseClient? purchaseClient,
    LearningVerifierTransport? verifierTransport,
    String? verifyUrl,
    String? entitlementsUrl,
  }) async {
    final dbProvider = databaseProvider ?? () => AppDatabase.instance.database;
    final loadOfferings = offeringLoader ?? LearningOfferingCatalog.loadBundled;
    final fallback = _fallbackService(
      databaseProvider: dbProvider,
      offeringLoader: loadOfferings,
    );

    final provider = (platformProvider ?? _currentPlatformProvider).call();
    if (provider == null) {
      return LearningCommerceBootstrapResult(
        status: LearningCommerceBootstrapStatus.unsupportedPlatform,
        service: fallback,
      );
    }
    if (sessionHeadersProvider == null) {
      return LearningCommerceBootstrapResult(
        status: LearningCommerceBootstrapStatus.missingSessionHeadersProvider,
        service: fallback,
      );
    }

    final offerings = await loadOfferings();
    final commerceCatalog = LearningCommerceCatalog.fromOfferings(
      offerings.offerings,
    );

    late final LearningStoreProductIds ids;
    try {
      ids = productIds ?? LearningStoreProductIds.fromEnvironment(provider);
    } on FormatException {
      return LearningCommerceBootstrapResult(
        status: LearningCommerceBootstrapStatus.invalidStoreProductIds,
        service: fallback,
      );
    }
    if (!ids.configured) {
      return LearningCommerceBootstrapResult(
        status: LearningCommerceBootstrapStatus.missingStoreProductIds,
        service: fallback,
      );
    }
    if (ids.provider != provider ||
        ids.productIds.length != commerceCatalog.productKeys.length ||
        !commerceCatalog.productKeys.containsAll(ids.productIds.keys)) {
      return LearningCommerceBootstrapResult(
        status: LearningCommerceBootstrapStatus.incompleteStoreProductIds,
        service: fallback,
      );
    }

    final resolvedVerifyUrl = verifyUrl ?? learningPurchaseVerifyUrl;
    final resolvedEntitlementsUrl = entitlementsUrl ?? learningEntitlementsUrl;
    if (resolvedVerifyUrl.trim().isEmpty ||
        resolvedEntitlementsUrl.trim().isEmpty) {
      return LearningCommerceBootstrapResult(
        status: LearningCommerceBootstrapStatus.missingVerifierEndpoints,
        service: fallback,
      );
    }

    late final HttpLearningPurchaseVerifier verifier;
    try {
      verifier = HttpLearningPurchaseVerifier(
        verifyUrl: resolvedVerifyUrl,
        entitlementsUrl: resolvedEntitlementsUrl,
        transport: verifierTransport,
        headersProvider: sessionHeadersProvider,
      );
    } on FormatException {
      return LearningCommerceBootstrapResult(
        status: LearningCommerceBootstrapStatus.invalidVerifierConfiguration,
        service: fallback,
      );
    }

    final store = LearningInAppPurchaseAdapter(
      providerType: provider,
      productIds: ids,
      client: purchaseClient,
    );
    final commerce = LearningCommerceCoordinator(
      catalog: commerceCatalog,
      provider: store,
      verifier: verifier,
    );
    final entitlements = SqliteVerifiedEntitlementRepository(
      databaseProvider: dbProvider,
    );
    final controller = LearningVerifiedEntitlementController(
      commerce: commerce,
      entitlements: entitlements,
    );
    final runtime = LearningCommerceRuntime(controller: controller);
    final service = DefaultLearningMaterialsService(
      entitlements: entitlements,
      installer: LearningPackageInstaller(
        catalogUrl: learningPackageCatalogUrl,
        entitlements: entitlements,
      ),
      databaseProvider: dbProvider,
      offeringLoader: () async => offerings,
      runtime: runtime,
    );

    return LearningCommerceBootstrapResult(
      status: LearningCommerceBootstrapStatus.configured,
      service: service,
      runtime: runtime,
    );
  }

  static DefaultLearningMaterialsService _fallbackService({
    required LearningMaterialsDatabaseProvider databaseProvider,
    required LearningOfferingCatalogLoader offeringLoader,
  }) {
    final entitlements = SqliteVerifiedEntitlementRepository(
      databaseProvider: databaseProvider,
    );
    return DefaultLearningMaterialsService(
      entitlements: entitlements,
      installer: LearningPackageInstaller(
        catalogUrl: learningPackageCatalogUrl,
        entitlements: entitlements,
      ),
      databaseProvider: databaseProvider,
      offeringLoader: offeringLoader,
    );
  }

  static LearningCommerceProvider? _currentPlatformProvider() {
    if (Platform.isAndroid) return LearningCommerceProvider.googlePlay;
    if (Platform.isIOS) return LearningCommerceProvider.appStore;
    return null;
  }
}
