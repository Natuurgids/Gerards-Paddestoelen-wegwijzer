import 'learning_access.dart';
import 'learning_offering.dart';

enum LearningCommerceProvider {
  googlePlay,
  appStore,
}

enum LearningPurchaseState {
  pending,
  purchased,
  restored,
  canceled,
  failed,
}

/// Store-supplied product presentation for one logical learning product.
///
/// [displayPrice] is authoritative for the current storefront and locale. It
/// must never be copied into learning content or offering manifests.
class LearningProductQuote {
  const LearningProductQuote({
    required this.productKey,
    required this.displayPrice,
    required this.currencyCode,
  });

  final String productKey;
  final String displayPrice;
  final String currencyCode;
}

/// Evidence emitted by a store adapter after a purchase or restore event.
///
/// The app must not grant an entitlement merely because this object exists.
/// The signed/receipt payload must first be checked by a trusted verifier.
class LearningPurchaseEvidence {
  const LearningPurchaseEvidence({
    required this.provider,
    required this.productKey,
    required this.transactionId,
    required this.verificationPayload,
    required this.state,
  });

  final LearningCommerceProvider provider;
  final String productKey;
  final String transactionId;
  final String verificationPayload;
  final LearningPurchaseState state;
}

/// Result returned by a trusted purchase verifier.
///
/// A verifier may be backed by a secure service that checks Google Play or App
/// Store transaction data and handles refunds/revocations. The learning UI and
/// package installer never inspect provider receipts directly.
class VerifiedLearningPurchase {
  const VerifiedLearningPurchase({
    required this.productKey,
    required this.entitlementKey,
    required this.active,
  });

  final String productKey;
  final String entitlementKey;
  final bool active;
}

abstract interface class LearningCommerceProviderAdapter {
  bool get configured;

  Stream<LearningPurchaseEvidence> get purchaseUpdates;

  Future<Map<String, LearningProductQuote>> loadProductQuotes(
    Set<String> productKeys,
  );

  Future<void> purchase(String productKey);

  Future<void> restorePurchases();
}

abstract interface class LearningPurchaseVerifier {
  Future<VerifiedLearningPurchase> verify(LearningPurchaseEvidence evidence);

  /// Reconcile all currently active permanent learning entitlements.
  ///
  /// This is distinct from a local cache. A production implementation should
  /// derive this snapshot from store-verified purchase state so refunds and
  /// revocations cannot be ignored indefinitely.
  Future<EntitlementSnapshot> restoreVerifiedEntitlements();
}

class LearningCommerceProductBinding {
  const LearningCommerceProductBinding({
    required this.productKey,
    required this.entitlementKey,
  });

  final String productKey;
  final String entitlementKey;
}

/// Provider-neutral mapping between public offering metadata and commerce.
///
/// No Google Play or App Store product identifier is stored here. A concrete
/// adapter may map the logical [productKey] to its own provider-specific ID.
class LearningCommerceCatalog {
  const LearningCommerceCatalog._(this.bindings);

  final Map<String, LearningCommerceProductBinding> bindings;

  factory LearningCommerceCatalog.fromOfferings(
    Iterable<LearningOffering> offerings,
  ) {
    final bindings = <String, LearningCommerceProductBinding>{};
    final entitlements = <String>{};
    for (final offering in offerings) {
      if (offering.productKey.trim().isEmpty ||
          offering.entitlementKey.trim().isEmpty) {
        throw const FormatException(
          'Learning commerce keys must be non-empty',
        );
      }
      if (bindings.containsKey(offering.productKey) ||
          !entitlements.add(offering.entitlementKey)) {
        throw const FormatException(
          'Learning commerce product and entitlement keys must be unique',
        );
      }
      bindings[offering.productKey] = LearningCommerceProductBinding(
        productKey: offering.productKey,
        entitlementKey: offering.entitlementKey,
      );
    }
    return LearningCommerceCatalog._(Map.unmodifiable(bindings));
  }

  Set<String> get productKeys => Set.unmodifiable(bindings.keys.toSet());

  LearningCommerceProductBinding? bindingForProduct(String productKey) =>
      bindings[productKey];
}

/// Coordinates product lookup and purchase verification without depending on a
/// specific store SDK.
class LearningCommerceCoordinator {
  const LearningCommerceCoordinator({
    required this.catalog,
    required this.provider,
    required this.verifier,
  });

  final LearningCommerceCatalog catalog;
  final LearningCommerceProviderAdapter provider;
  final LearningPurchaseVerifier verifier;

  bool get configured => provider.configured;

  Future<Map<String, LearningProductQuote>> loadQuotes() async {
    if (!configured) return const <String, LearningProductQuote>{};
    final quotes = await provider.loadProductQuotes(catalog.productKeys);
    for (final entry in quotes.entries) {
      if (!catalog.bindings.containsKey(entry.key) ||
          entry.value.productKey != entry.key ||
          entry.value.displayPrice.trim().isEmpty ||
          entry.value.currencyCode.trim().isEmpty) {
        throw StateError('Commerce provider returned an invalid product quote');
      }
    }
    return Map.unmodifiable(quotes);
  }

  Future<void> purchase(String productKey) async {
    if (!configured) {
      throw StateError('Learning commerce provider is not configured');
    }
    if (!catalog.bindings.containsKey(productKey)) {
      throw ArgumentError.value(productKey, 'productKey', 'Unknown learning product');
    }
    await provider.purchase(productKey);
  }

  Future<void> restorePurchases() async {
    if (!configured) {
      throw StateError('Learning commerce provider is not configured');
    }
    await provider.restorePurchases();
  }

  Future<VerifiedLearningPurchase> verifyEvidence(
    LearningPurchaseEvidence evidence,
  ) async {
    final binding = catalog.bindingForProduct(evidence.productKey);
    if (binding == null) {
      throw StateError('Purchase evidence references an unknown learning product');
    }
    if (evidence.state != LearningPurchaseState.purchased &&
        evidence.state != LearningPurchaseState.restored) {
      throw StateError('Only completed purchases may be verified for entitlement');
    }
    if (evidence.transactionId.trim().isEmpty ||
        evidence.verificationPayload.trim().isEmpty) {
      throw StateError('Purchase evidence is incomplete');
    }

    final verified = await verifier.verify(evidence);
    if (verified.productKey != binding.productKey ||
        verified.entitlementKey != binding.entitlementKey) {
      throw StateError('Verified purchase does not match the learning offering');
    }
    return verified;
  }
}
