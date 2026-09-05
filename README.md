# Gerards Paddestoelen Wegwijzer

Offline-first Flutter application for mushroom determination and mycology education.

## Product scope

Gerards Paddestoelen Wegwijzer is currently a **determination + education** tool. It is not currently an observation-registration or occurrence-mapping app.

The codebase intentionally retains privacy-safe observation/location infrastructure as a deferred integration boundary for a possible future Aperture integration. That infrastructure is not a main product feature. Fieldora/Aperture ecosystem integration is a much-later improvement; see `docs/product-roadmap.md`.

Location privacy remains strict: never expose raw coordinates for vulnerable or sensitive species, never reconstruct precision hidden by a source, and never make source-provided locations more precise. Source/provenance and consultation/access dates must remain preserved.

## Current catalogue and licensed enrichment

The authoritative packaged catalogue contains **12,525 species**, including **12,509 additions** from the Checklist Dutch Species Register / Nederlands Soortenregister, Naturalis Biodiversity Center (CC BY 4.0).

Current reviewed enrichment locks are:

- German DGfM names: 1,050
- English UKSI names: 12
- IUCN statuses: 118
- NSR additions: 12,509
- total catalogue: 12,525

CI protects these reviewed source counts and exact licence expectations. IUCN data comes only from the reviewed GBIF-hosted CC BY 4.0 dataset used by this project. IUCN status is a **global conservation status**, not legal protection. A separate Dutch Red List architecture is supported, but no Dutch fungal Red List species/status table is imported until explicit commercial/reuse rights for such a table are established.

The catalogue is much broader than the curated `species_trait` determination knowledge. Do not interpret catalogue coverage as complete determination coverage for all 12,525 species.

## Implemented

- Flutter mobile application foundation.
- Offline SQLite database; no network is needed for species browsing, determination or packaged training.
- Dutch (`nl`), English (`en`) and German (`de`) content foundation.
- Developer-editable species/taxonomy, determination-trait, field-data, gallery and training manifests synchronized into SQLite.
- Normalized taxonomy, translated species content, localized determination traits, measurements, region-tagged seasonality, image metadata, lessons/questions and training progress.
- Indexed scientific/common-name lookup, localized trait lookup, species-trait filtering, numeric measurement lookup, regional month/season lookup, image ordering and lesson/question joins.
- Offline species catalogue with local search.
- Trait-based determination with weighted candidate ranking using one aggregate morphology query plus one optional field-evidence query.
- Optional determination evidence from cap diameter, stem height, stem diameter and an explicitly selected regional season/month reference.
- Region choices and explanatory notes loaded dynamically from `field_data.json`.
- Species detail pages backed by SQLite, including measurements and region-labelled fruiting season.
- Offline lessons and quizzes with best score and attempt count persisted locally.
- Provider-neutral learning entitlement/access model for future premium courses; no payment SDK or purchase flow is implemented.
- Permanent mushroom-consumption safety notice on current user-facing screens.
- Privacy-safe observation/location infrastructure retained for possible future ecosystem use without exposing it as the current product focus.
- GitHub Actions source/licence regression locks, analysis/tests, packaged reference-database generation and production Android release APK build.

## Run on Windows

Prerequisite: install Flutter and make sure `flutter doctor` succeeds.

From PowerShell in the repository root:

```powershell
.\tool\bootstrap.ps1
flutter run
```

The bootstrap script generates standard Android/iOS Flutter platform scaffolding, downloads dependencies, runs the analyzer and runs the test suite. Platform scaffolding is generated rather than hand-maintained during this application phase.

## Database design

Schema creation and migrations live in `lib/src/data/database_schema.dart`; `lib/src/data/app_database.dart` owns opening, configuration and manifest synchronization. The app is currently **schema version 9**. Developer-editable manifests are synchronized into SQLite whenever the database opens.

The normalized model separates:

- taxonomy: `taxon`, `species`
- species translations: `species_text`
- determination: `trait`, `trait_text`, `trait_option`, `trait_option_text`, `species_trait`
- quantitative field characters: `species_measurement`
- fruiting season with regional provenance: `species_season`, keyed by `(species_id, region_code, month)`
- galleries: `species_image`
- normalized conservation data: `species_conservation_status`
- reference provenance: `reference_source`
- education: `lesson`, `lesson_text`, `question`, `question_text`, `answer_option`, `answer_option_text`
- user learning state: `training_progress`

Important lookup columns are indexed, including taxonomy parents, scientific/common names, translated trait labels, species traits, measurement ranges, regional season months, gallery order and training relations. Foreign keys are enabled, SQLite runs in WAL mode, and a busy timeout reduces transient lock failures.

`AppDatabase` shares one in-flight opening future. Concurrent first reads therefore await the same database open/import operation instead of racing multiple opens.

Repository classes accept injectable database providers where needed for in-memory SQL tests while normal application code uses the production database singleton.

## Content manifests

The application keeps content maintenance separate from Flutter UI source code:

- `assets/data/species_catalog.json` — taxonomy, species metadata and NL/EN/DE species text.
- `assets/data/identification_traits.json` — localized determination traits/options and weighted species mappings.
- `assets/data/field_data.json` — localized `season_regions`, normalized numeric measurements and one or more `season_datasets` per species, each with its own `region_code`.
- `assets/data/species_images.json` — gallery paths, angle/order, primary image and optional attribution/licence metadata.
- `assets/data/training_content.json` — multilingual lessons, questions, answers and explanations.

Importers validate manifest structure before applying writes. Catalogue and trait imports reject invalid IDs, translations and references before mutation; field and gallery imports validate their authoritative datasets before replacement; training content validates before insert/update and deliberately does not delete lessons, so persisted `training_progress` is not removed as a side effect of content synchronization.

Stable numeric IDs should not be reused for a different biological or educational meaning after release.

## Adding or enriching species

Add or enrich species only from reviewed, appropriately licensed sources. Do not guess biological content and do not copy copyrighted prose merely because it is publicly visible.

For curated determination coverage:

1. Add or verify taxonomy/species data using stable IDs.
2. Add complete localized species text only where rights and sourcing permit.
3. Add reviewed identifying trait relations in `assets/data/identification_traits.json`.
4. Add sourced measurements and validated regional calendars in `assets/data/field_data.json`.
5. Add media metadata only with stable source URL, creator/author, licence/attribution and fallback behaviour.

`edible_status` and `toxicity_level` are descriptive metadata only. Neither contributes to determination confidence.

## Determination traits, measurements and seasonality

Each developer-managed trait contains a stable id/code, structural category, NL/EN/DE label and one or more localized options. `species_trait` maps the curated subset of species to applicable options and diagnostic weights.

`assets/data/field_data.json` stores quantitative data separately from prose. Measurements have machine-readable codes, minimum/maximum values and units. The manifest also declares localized `season_regions` and one or more regional `season_datasets` per species.

The current schema retains the regional `(species_id, region_code, month)` season key. The importer accepts the legacy `season_region` + `season` shape for backward compatibility, while new content should use `season_datasets`.

## Training and future premium courses

`assets/data/training_content.json` defines packaged lessons, localized lesson text, questions, answer choices and explanations. Free/basic lessons remain offline assets and quiz progress, attempts and best score remain local in SQLite.

`lib/src/data/learning_access.dart` establishes the provider-neutral access boundary for future premium education:

**content → entitlement → access**

Logical entitlement keys are deliberately separate from commerce/product identifiers. Google Play Billing, Apple StoreKit, an approved external/web portal or another compliant backend may later grant the same logical entitlement without coupling educational content to one provider. No real payment SDK, in-app web-payment button, account backend or store purchase flow is implemented yet.

Training progress remains independent of entitlement/content refreshes.

## Determination scoring

The determination screen stores selected observable trait options. Morphological candidates are scored from the normalized `species_trait` table using each relation's diagnostic weight in one indexed aggregate query.

Users may optionally add cap diameter, stem height, stem diameter and a month. Month evidence is only enabled after the user explicitly selects a regional season reference loaded from the manifest.

When at least one morphological trait is selected, morphology contributes **80%** of the combined ranking and optional field evidence contributes **20%**. If no morphology is selected, available field evidence may rank the catalogue by itself. Results expose morphology matches and field-data matches separately.

The result score is an educational narrowing/ranking aid only. It is **not** an edibility confidence score and is not a statistical probability that a mushroom has been identified correctly.

## Tests and release CI

Tests cover content contracts, validation-before-mutation behaviour, preservation of user-owned training progress, determination scoring, regional season handling, SQL query plans, conservation/provenance rules and the provider-neutral premium-learning access boundary.

GitHub Actions also rebuilds and verifies the reviewed catalogue/enrichment snapshot and exact source/licence locks before Flutter analysis/tests. A successful pipeline builds a production release APK and uploads it as `gerards-paddestoelen-wegwijzer-android-release`.

## Safety

Determination output is educational assistance, not an edibility guarantee. The permanent safety notice must remain: never consume a mushroom solely because of an app determination; edible specimens should be verified by a qualified local expert.

Conservation or Red List status must never be presented as legal-protection status unless a separate authoritative legal source explicitly establishes that protection.
