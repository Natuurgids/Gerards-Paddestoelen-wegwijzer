# Downloadable learning package installer contract

The downloadable learning package channel is separate from core reference-data updates and from payment-provider integration.

- The public app repository may contain only safe offering metadata such as logical package/course/entitlement/product keys, localized titles and summaries.
- Paid lesson bodies, quizzes and remote delivery metadata (content version, package path, byte size and SHA-256) must be published from separately controlled content hosting, not committed to this public repository.
- The prototype v1 specialist payloads previously committed to this public repository remain accessible in Git history and therefore must not be marketed or reused as protected paid content. Commercial releases must use newly authored payload revisions from controlled hosting.
- A production paid-learning catalogue may be browsed without owning each individual package, but it is still fetched only through the authenticated learning-delivery transport. An unconfigured/fail-closed app does not make anonymous catalogue or package requests.
- Package bytes are not requested until the logical entitlement declared by that package is granted.
- Entitlements are provider-neutral application keys; store product identifiers remain metadata and are not consulted by the installer.
- The catalog endpoint must be explicit HTTPS without user info. Package paths resolve relative to the catalog and must remain on the same trusted origin.
- Production paid delivery uses `AuthenticatedLearningPackageByteSource`. Runtime session headers are requested separately for every catalogue/package request so short-lived credentials can rotate. The source rejects cross-origin requests before asking for headers, and the HTTP transport refuses redirects so credentials cannot be forwarded to another host.
- No reusable delivery secret may be stored in source, Dart defines, public offering metadata or package manifests. The same authenticated application session used by the trusted verifier supplies delivery request headers at runtime.
- Downloads use bounded responses with redirects disabled. Exact catalog-declared byte size and SHA-256 are checked before parsing or database writes.
- Package metadata must exactly match its catalog descriptor and use `entitlement_required` + `downloadable` course access.
- Training content is imported inside the same SQLite transaction that records installed package version state and package-to-lesson ownership.
- Installed package state uses the namespaced `bundled_content_state` key `learning-package:<package_key>`; lesson ownership uses `learning-package-lesson:<lesson_id>:<package_key>`. Both are distinct from `reference-content` and `core-reference-content`.
- A downloadable lesson id may belong to only one installed package. Cross-package lesson-id collisions reject the whole install transaction.
- A package refresh replaces that package's ownership map. Lessons retired by the new package revision remain stored with their existing `training_progress`, but they are no longer exposed as belonging to the installed package.
- Same or older installed versions do not download again once a lesson ownership map exists. A legacy installed state without ownership is re-downloaded and validated so the map can be backfilled safely.
- Existing `training_progress` is never deleted or reset by installation or package refresh.
- Built-in learning remains outside this channel and permanently free.
- Store price/currency never belongs in either the public offering metadata or lesson payload. Displayed price must come from the configured commerce provider.

The production commerce bootstrap must require protected delivery configuration before enabling Buy/Restore. If authenticated session state, verifier endpoints, store product mappings or the paid catalogue endpoint are missing/invalid, purchases and new paid downloads remain disabled while already-installed verified content can continue to work offline.
