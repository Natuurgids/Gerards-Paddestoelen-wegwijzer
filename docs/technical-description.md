# Technical description

## Technology baseline

Gerards Paddestoelen Wegwijzer is a Flutter application with a local SQLite data layer. The design is offline-first: the packaged biological catalogue, determination data, bundled education and packaged reference media do not require a live backend for ordinary use.

Generated Android/iOS platform scaffolding is configured by repository tooling rather than treated as the primary application source. Release CI regenerates/configures the platform layer and validates the resulting release artifact.

## Runtime layers

### Presentation

Flutter screens present catalogue search, determination, species details, galleries, education, quizzes and settings/navigation. UI code consumes repositories/services and should not contain provider-specific payment or storage logic.

### Data access

`lib/src/data/app_database.dart` owns database opening/configuration and manifest synchronization. Schema and migrations are defined in `lib/src/data/database_schema.dart`.

The current database schema is version 9. SQLite uses foreign keys, WAL mode and a busy timeout. `AppDatabase` shares an in-flight opening future so concurrent first reads do not race separate database initialization/import operations.

Repository classes use the production database singleton by default and can accept injectable providers for in-memory tests.

### Normalized data model

The principal data areas are:

- taxonomy: `taxon`, `species`;
- localized species text: `species_text`;
- determination: `trait`, `trait_text`, `trait_option`, `trait_option_text`, `species_trait`;
- quantitative field characters: `species_measurement`;
- regional seasonality: `species_season`;
- galleries: `species_image`;
- conservation: `species_conservation_status`;
- provenance: `reference_source`;
- education: `lesson`, `lesson_text`, `question`, `question_text`, `answer_option`, `answer_option_text`;
- local learning state: `training_progress`.

Indexes cover important taxonomy, name, trait, measurement, season, gallery and education lookups.

## Content pipeline

Developer-maintained manifests under `assets/data/` are the content boundary between biological/educational data and Flutter UI source:

- `species_catalog.json`;
- `identification_traits.json`;
- `field_data.json`;
- `species_images.json`;
- `training_content.json`.

Importers validate authoritative manifest structure before mutating local state. Stable identifiers must not be reused for different biological or educational meanings after release.

The release pipeline also regenerates/revalidates reviewed reference datasets and source/licence locks so accidental source or licence drift fails CI.

## Offline media packaging

Species images are represented in the gallery manifest and stored as Flutter assets. Because Flutter asset discovery does not automatically solve arbitrary nested generated image layouts, repository tooling prepares the nested species asset directories before Android/Windows release packaging.

Release verifiers inspect the built artifact rather than assuming that source-tree presence means packaged presence. The verified Android release currently contains all 7,483 images referenced by the packaged species-image set.

## Determination engine

Morphological selections are resolved against normalized `species_trait` relations using diagnostic weights. Candidate scoring is performed with aggregate database queries rather than loading the complete catalogue into application-side filtering loops.

Optional measurement and regional-season evidence is evaluated separately. When morphology exists, morphology contributes 80% of the combined ranking and optional field evidence contributes 20%. With no morphology selected, available field evidence can rank candidates independently.

The score is a ranking aid only and is deliberately separate from `edible_status` and `toxicity_level` metadata.

## Education subsystem

Bundled education is imported into the same local database while user progress remains separately persisted. Training-content synchronization deliberately avoids deleting lessons in a way that would remove user-owned progress as a side effect.

Additional learning packages use a separate package lifecycle. The package installer validates package contracts, size/hash/integrity requirements and entitlement state before activation. Commerce and package bytes remain distinct concerns.

## Commerce and entitlements

The logical boundary is:

`learning offering -> logical product/entitlement -> commerce adapter -> trusted verifier -> durable entitlement -> package access`

Provider identifiers are deployment configuration and do not belong in lesson/package content. The existing concrete Flutter mobile-store adapter is behind provider-neutral interfaces.

Verified entitlements are persisted through `SqliteVerifiedEntitlementRepository` under a reserved `learning-entitlement:` namespace in `bundled_content_state`. This avoids coupling entitlement storage to core dataset state or training progress.

Purchase evidence is processed in this order:

1. trusted verification;
2. validation of logical product/entitlement binding;
3. durable entitlement persistence;
4. completion/acknowledgement of the retained store transaction.

The local entitlement cache is an offline access cache, not a receipt verifier.

## Trusted network boundary

Verifier and protected-package endpoints are runtime/deployment configuration. Reusable backend/provider secrets must not be embedded in source code, Dart defines, APKs or AABs.

The implemented HTTP verifier/package transports require HTTPS, constrain origins/redirect behaviour and bound response/package sizes. Authentication headers are runtime state and are requested when needed rather than compiled into the application.

If required configuration/authentication is absent or invalid, production commerce fails closed: new paid purchases/downloads are disabled while already installed and previously verified content can remain usable offline.

## Build-time product modularity

Reusable infrastructure should be domain-neutral where that provides real reuse, but biological domains are selected at product/build time rather than installed as runtime plugins.

A future product configuration can select application identity, branding, catalogue assets, trait implementation and education catalogue for a separately compiled app. For example, a tree or bird application can reuse database, navigation, localisation, education/package and commerce infrastructure while shipping only its own domain data.

The mushroom app must not expose a runtime mechanism to turn itself into a bird/tree app by downloading another domain.

## AI boundary

AI is intentionally outside the core data/determination dependency graph. A future implementation should use a small service interface with replaceable implementations such as an external test provider and a later self-hosted service. Provider credentials and privileged inference infrastructure belong server-side.

## Android release configuration

The Google Play release path currently verifies:

- application ID `nl.natuurgids.gerards_paddestoelen_wegwijzer`;
- Android `minSdk` 24;
- Android `targetSdk` 36 or newer;
- expected release permission set (currently `INTERNET` only);
- valid AAB structure;
- packaged species-image count/content expectations;
- selected cleartext/credential packaging checks.

CI also runs Flutter analysis and the automated test suite before release artifact upload.

The latest successful compliance run for this branch produced artifact `gerards-paddestoelen-wegwijzer-android-play-release` from head `f27a1dbc4edf47db61e697577933bb80ae515ca6`. Release documentation should treat CI verification as repository/build evidence, not as a substitute for Play Console signing, declarations or review.

## Related documentation

- `docs/functional-description.md`
- `docs/architectural-description.md`
- `docs/learning-commerce-contract.md`
- `docs/learning-package-installer-contract.md`
- `docs/learning-package-publishing.md`
- `docs/learning-hosting-verifier-requirements.md`
- `docs/reference-data-plan.md`
