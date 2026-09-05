# Learning commerce contract

Paid learning commerce is separate from learning content delivery and from the core reference-data updater.

- The seven public learning offerings keep provider-neutral `product_key` and `entitlement_key` values.
- Google Play and App Store product identifiers belong only in a concrete commerce adapter/configuration, never in learning content or package manifests.
- Specialist packs are permanent one-time learning unlocks unless a later product decision explicitly introduces another model.
- Display price and currency are authoritative store data for the current storefront/locale. The app must never fall back to a hardcoded `€2.99` value when store data is unavailable.
- Purchase callbacks do not grant an entitlement by themselves. Only completed purchase/restore evidence may be submitted to a trusted verifier.
- Verified purchase output must match the offering's logical product and entitlement pair before access can be granted.
- Pending, canceled and failed purchases do not grant learning access.
- Restore is a first-class operation. A trusted verifier must be able to reconcile the currently active permanent entitlement snapshot, including refunds/revocations where the store reports them.
- The learning package installer continues to ask only whether a logical entitlement is granted; it never parses store receipts or provider identifiers.
- Paid package hosting remains separately controlled. Commerce success and content download are distinct operations.

## Supported purchase platform baseline

As of 2026-09-05 the app adopts the official Flutter `in_app_purchase` 3.3.x line as its purchase SDK baseline. That line supports Android SDK 24+ and iOS 13.0+. Google Play Billing Library 7 reached its normal new-app/update deadline on 2026-08-31, so retaining an older purchase SDK solely to preserve Android 21 is not the release baseline.

This repository generates Android and iOS scaffolding rather than committing the platform trees. After `flutter create`, run `python3 tool/configure_generated_platforms.py` before dependency installation or release builds. CI runs the same command and its regression tests. The script sets Android `minSdk` to 24, ensures the generated Android release manifest includes `android.permission.INTERNET`, sets iOS deployment targets and `MinimumOSVersion` to 13.0, and fails if a future Flutter template no longer contains the expected declarations. Release Internet access is required by the existing core/package update channels and by trusted verifier HTTPS when those channels are configured.

## Store adapter configuration

`LearningInAppPurchaseAdapter` is the concrete bridge to Flutter's official `in_app_purchase` API. It still implements the provider-neutral `LearningCommerceProviderAdapter`, so the materials UI and learning package installer never depend on Google Play or App Store SDK types.

Provider-specific product IDs are deployment configuration rather than learning content. They may be supplied as JSON objects through compile-time Dart defines:

- `LEARNING_GOOGLE_PLAY_PRODUCT_IDS`
- `LEARNING_APP_STORE_PRODUCT_IDS`

Each JSON object maps the existing logical offering `product_key` to the corresponding provider product identifier. The mapping must use non-empty unique provider IDs. No provider ID is invented by the app and no price is stored in this mapping.

The adapter queries `ProductDetails` from the active store and maps the provider-formatted price and currency back to the logical learning product. Missing products produce no fallback quote. Purchase uses the store's non-consumable flow and Restore delegates to the store restore flow.

Purchase updates are converted to `LearningPurchaseEvidence` only for configured provider product IDs. Unknown store products are ignored. `serverVerificationData` is passed to the trusted verifier; `purchaseID` is retained when the SDK provides one but is allowed to be empty because the official SDK type makes it nullable.

A purchased/restored event is not acknowledged merely because the store emitted it. Trusted verification must first validate the logical product/entitlement pair. The production processing path must also persist the resulting entitlement state before it asks the store adapter to call `completePurchase` for the exact retained transaction. Failed, pending, canceled, malformed or mismatched verification therefore cannot complete the purchase through this path.

## Durable verified entitlement cache

`SqliteVerifiedEntitlementRepository` implements the same provider-neutral `EntitlementRepository` read interface used by learning access and package installation. It stores only verified logical entitlement keys under the reserved `learning-entitlement:` namespace in the existing `bundled_content_state` table. This avoids a database schema bump that would otherwise make current core dataset schema-v9 packages incompatible.

The entitlement namespace is independent from bundled reference-content, core dataset, installed learning-package and training-progress state. Full entitlement reconciliation deletes/replaces only `learning-entitlement:` rows in one transaction and therefore cannot reset reference content, installed package ownership or quiz progress.

`LearningVerifiedEntitlementController.processEvidence` follows this order:

1. trusted verifier validates purchase/restore evidence and its logical product→entitlement binding;
2. the verified active/inactive entitlement is persisted locally;
3. only after persistence succeeds is the exact retained store transaction completed.

If entitlement persistence fails, the store transaction is left incomplete for redelivery/recovery. If completion fails after persistence, reprocessing is idempotent because the logical entitlement write is idempotent and the verifier remains authoritative.

For Restore, `restoreAndReconcile` first asks the store to restore purchases and then replaces the local entitlement namespace from `LearningPurchaseVerifier.restoreVerifiedEntitlements()`. Entitlements unknown to the current app version are ignored, which allows a newer backend/account state to coexist with an older app without granting access to content that app does not know.

The local cache is an offline access cache, not a receipt verifier. Provider receipts are never trusted merely because they exist on-device.

## Trusted verifier transport

`HttpLearningPurchaseVerifier` implements `LearningPurchaseVerifier` against separately controlled HTTPS infrastructure. The two public deployment endpoints are supplied through compile-time configuration:

- `LEARNING_PURCHASE_VERIFY_URL`
- `LEARNING_ENTITLEMENTS_URL`

Both endpoints must use HTTPS, contain no URL user credentials or fragment, and share the same origin. The default transport refuses redirects, limits verifier responses to 64 KiB and applies a finite network timeout. This prevents a verifier request from silently following evidence or session headers to another host.

The purchase verification request contains only contract version, provider, logical `product_key`, optional provider transaction ID and the store's server-verification payload. It never sends locally invented purchase proof. A successful verification response contains only logical `product_key`, logical `entitlement_key` and an `active` boolean; `LearningCommerceCoordinator` still validates that product/entitlement pair against the bundled offering catalogue before access changes.

The entitlement-reconciliation endpoint returns the authoritative active logical entitlement keys for the authenticated session. Runtime authentication/session headers may be supplied through `LearningVerifierHeadersProvider`. No reusable verifier/backend secret may be embedded in source code, Dart defines or the APK. Endpoint URLs are public configuration; credentials are runtime state.

## Protected paid-content delivery

`AuthenticatedLearningPackageByteSource` binds paid catalogue/package downloads to the configured `LEARNING_PACKAGE_CATALOG_URL` HTTPS origin. The same runtime session-header provider used by the trusted verifier supplies request headers for delivery, but the headers are requested anew for every request so short-lived tokens can rotate.

The authenticated byte source rejects a URI outside the configured catalogue origin before requesting session headers. The production learning-package HTTP transport also refuses redirects, validates caller-supplied header names/values and enforces the caller's byte limit. This prevents account/session credentials from being silently forwarded to another host.

The remote catalogue may describe all specialist products for the authenticated app session, but package bytes are still not fetched until the local logical entitlement is granted. Catalogue/package hashes and exact package byte size remain mandatory integrity checks before import. Runtime authentication is access control; SHA-256 remains package integrity.

The fail-closed bootstrap deliberately constructs its fallback materials service with paid delivery disabled (`catalogUrl: ''`). Previously installed and verified content can therefore remain usable offline, but an invalid/missing session, store mapping, verifier or delivery endpoint cannot trigger anonymous paid-content downloads.

## Runtime processing and UI refresh

`LearningCommerceRuntime` is the long-lived processor for configured store purchase updates. It serializes completed purchase/restore evidence so verification, entitlement persistence and store completion cannot race. Pending, canceled and failed store states are not submitted for entitlement processing. A verification/persistence failure is reported on the runtime error stream but does not terminate the store subscription, so later valid purchases can still be processed.

After a verified entitlement is persisted, the runtime emits an entitlement-change signal. `LearningMaterialsScreen` listens only when its service exposes this optional capability and reloads local state, so a purchase launched from the UI remains locked until the later trusted verification event actually changes the durable entitlement cache.

`DefaultLearningMaterialsService.standard()` now reads `SqliteVerifiedEntitlementRepository` instead of an always-empty repository. This means previously verified ownership continues to work offline even when the store/verifier are currently unavailable. The same durable repository is used by the learning package installer, preserving one entitlement source of truth.

A configured long-lived runtime may be injected through `DefaultLearningMaterialsService` and then through `MycologyApp`/`HomeScreen` into the materials screen. The default `main.dart` does not create such a runtime or invent authentication, provider IDs or verifier sessions. Production commerce therefore remains fail-closed until a real authenticated bootstrap supplies those dependencies; the runtime lifecycle is available without weakening the security boundary.

## Fail-closed deployment bootstrap

`LearningCommerceBootstrap.fromEnvironment()` is the single composition gate for a future authenticated production bootstrap. It selects Google Play only on Android and App Store only on iOS, loads the bundled public offering catalogue, and requires the active platform's store mapping to contain exactly the same logical product keys as the catalogue. Missing, malformed, incomplete or wrong-platform mappings do not partially enable commerce.

Both trusted verifier endpoints and the protected paid-package catalogue endpoint must be configured and valid, and a runtime `LearningVerifierHeadersProvider` must be supplied by the caller before the bootstrap will construct the official store adapter, verifier, authenticated package transport, durable entitlement repository, controller and long-lived runtime. The header provider is deliberately not sourced from Dart defines or repository secrets: it represents runtime session/account state owned by a future authenticated application bootstrap.

Ordinary deployment incompleteness returns an explicit `LearningCommerceBootstrapStatus` and an offline-capable materials service with purchases and new paid downloads disabled. Previously verified cached entitlements remain readable and already-installed entitled content can remain usable offline. A fully configured result owns the runtime subscription and must be closed with `LearningCommerceBootstrapResult.close()` when its application/session lifecycle ends.

`main.dart` remains intentionally unconfigured. Adding the bootstrap factory does not by itself activate Buy/Restore in a production release and does not create an anonymous verifier identity. Real platform product IDs, a deployed trusted verifier, authenticated session ownership and separately controlled paid-content hosting are still release prerequisites.

The verifier transport, runtime and bootstrap still do not make the currently public repository a paid-content host. Commercial paid revisions must remain newly authored and hosted on separately controlled content infrastructure.
