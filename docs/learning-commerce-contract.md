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

As of 2026-09-05, the current official Flutter `in_app_purchase` line supports App Store and Google Play but its latest supported-platform matrix raises the Android floor to SDK 24 and iOS to 13. Concrete plugin adoption is therefore a separate release/platform-support decision rather than an implicit side effect of this contract PR.
