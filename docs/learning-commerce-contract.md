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
- The current build remains safely unconfigured until a concrete store adapter, provider-specific product-ID mapping and trusted verification path are supplied.

## Supported purchase platform baseline

As of 2026-09-05 the app adopts the official Flutter `in_app_purchase` 3.3.x line as its purchase SDK baseline. That line supports Android SDK 24+ and iOS 13.0+. Google Play Billing Library 7 reached its normal new-app/update deadline on 2026-08-31, so retaining an older purchase SDK solely to preserve Android 21 is not the release baseline.

This repository generates Android and iOS scaffolding rather than committing the platform trees. After `flutter create`, run `python3 tool/configure_generated_platforms.py` before dependency installation or release builds. CI runs the same command and its regression tests. The script sets Android `minSdk` to 24, iOS deployment targets and `MinimumOSVersion` to 13.0, and fails if a future Flutter template no longer contains the expected declarations.

The purchase SDK baseline does not itself enable commerce. The production learning-materials service remains unconfigured until a concrete store adapter, provider-specific product-ID mapping and trusted purchase verifier are supplied.
