# Downloadable learning package installer contract

The downloadable learning package channel is separate from core reference-data updates and from payment-provider integration.

- The app may load the remote learning package catalog for browsing without an entitlement.
- Package bytes are not requested until the logical entitlement declared by that package is granted.
- Entitlements are provider-neutral application keys; store product identifiers remain metadata and are not consulted by the installer.
- The catalog endpoint must be explicit HTTPS without user info. Package paths resolve relative to the catalog and must remain on the same trusted origin.
- Downloads use bounded responses with redirects disabled. Exact catalog-declared byte size and SHA-256 are checked before parsing or database writes.
- Package metadata must exactly match its catalog descriptor and use `entitlement_required` + `downloadable` course access.
- Training content is imported inside the same SQLite transaction that records installed package version state.
- Installed state uses the namespaced `bundled_content_state` key `learning-package:<package_key>`; this is distinct from `reference-content` and `core-reference-content`.
- Same or older installed versions do not download again. Downgrades are never applied automatically.
- Existing `training_progress` is never deleted or reset by installation or package refresh.
- Built-in learning remains outside this channel and permanently free.

A later UI/payment slice may browse this catalog, display provider-authoritative prices, request purchases/restores through a commerce adapter, and call this installer after entitlement confirmation. The installer itself remains independent of Google Play, App Store, web payment, bundles, or subscription policy.
