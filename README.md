# Gerards Paddestoelen Wegwijzer

Offline-first Flutter application for mushroom determination, reference browsing and mycology education.

## Product scope

Gerards Paddestoelen Wegwijzer is a standalone mushroom product. It combines a broad offline fungal catalogue, reference images, trait-based determination, species details and offline education.

The project is intentionally modular, but biological domains are **build-time products**, not runtime downloadable plugins. A future trees or birds guide should be compiled and released as a separate application while reusing appropriate infrastructure from this codebase.

The app is not currently an observation-registration or occurrence-mapping product. Privacy-safe observation/location infrastructure is retained only as a deferred integration boundary.

## Current packaged data

- 12,525 species in the authoritative packaged catalogue.
- 12,509 catalogue additions from the Checklist Dutch Species Register / Nederlands Soortenregister, Naturalis Biodiversity Center (CC BY 4.0).
- 7,483 packaged GBIF reference images in the verified Android release.
- reviewed German DGfM names: 1,050.
- reviewed English UKSI names: 12.
- reviewed IUCN statuses: 118.

CI protects reviewed source counts and licence expectations. Catalogue coverage is broader than curated determination coverage; catalogue presence does not mean every species has complete traits, translations or imagery.

## Main functions

- Offline species catalogue and indexed scientific/common-name search.
- Trait-based determination with weighted candidate ranking.
- Optional measurement and explicitly selected regional season/month evidence.
- Species detail pages with available measurements, seasonality, conservation/provenance and image galleries.
- Image attribution/licence/source display where supplied by reviewed metadata.
- Dutch, English and German content foundation.
- Offline lessons and quizzes with local best score and attempt count.
- Provider-neutral learning entitlement/package boundaries for optional additional education.
- Free additional learning/activity packages can use the same package infrastructure without a payment step.
- Permanent mushroom-consumption safety guidance.

## Architecture

The governing architecture is:

**shared engineering, separate compiled products, separate domain content.**

Reusable infrastructure includes the Flutter application shell, localisation, SQLite/data access, image/provenance handling, education, package installation, entitlement/commerce boundaries and release tooling. Mushroom-specific biological data and determination semantics remain part of this compiled mushroom product.

Optional paid education is separated into content, entitlement and commerce layers. Payment/provider callbacks do not directly unlock lessons; trusted verification must establish a logical entitlement, which is then persisted for offline access. Package delivery and package integrity are separate from payment processing.

AI is not a core dependency. If tested later, it should sit behind a replaceable service boundary so an external provider can be evaluated first and a self-hosted service can replace it later without restructuring the field guide.

## Data and storage

The app uses SQLite. Schema/migrations live in `lib/src/data/database_schema.dart`; `lib/src/data/app_database.dart` owns opening, configuration and manifest synchronization. The current schema is version 9.

Principal normalized areas are taxonomy/species, translated species text, determination traits/options, species-trait relations, measurements, regional seasonality, galleries, conservation/provenance, education content and local training progress.

Developer-maintained content lives under `assets/data/`:

- `species_catalog.json`
- `identification_traits.json`
- `field_data.json`
- `species_images.json`
- `training_content.json`

Importers validate authoritative content before mutation. Stable biological/educational identifiers must not be reused for another meaning after release.

## Determination scoring

Morphological candidates are ranked from normalized `species_trait` relations and diagnostic weights. Optional cap/stem measurements and regional month evidence can supplement morphology.

When morphology is selected, morphology contributes 80% of the combined ranking and optional field evidence contributes 20%. Without morphology, available field evidence may rank candidates independently.

The score is an educational narrowing/ranking aid. It is not an identification probability or an edibility confidence score. `edible_status` and `toxicity_level` do not contribute to determination confidence.

## Education and additional packages

Bundled lessons remain offline assets and training progress remains local.

Additional learning content is modular relative to the core field guide. It can be free or entitlement-protected. Paid package installation asks only whether the required logical entitlement is verified; it does not contain store/provider receipt logic.

The repository contains provider-neutral commerce interfaces and a concrete mobile-store adapter path, but production commerce remains fail-closed until real product mappings, trusted verification, authenticated runtime state and protected package hosting are supplied. Reusable backend/merchant secrets must never be embedded in the APK/AAB.

## Run on Windows

Install Flutter and ensure `flutter doctor` succeeds, then from PowerShell in the repository root:

```powershell
.\tool\bootstrap.ps1
flutter run
```

The bootstrap process generates/configures standard platform scaffolding, installs dependencies and runs project checks.

## Release CI

CI rebuilds/verifies reviewed catalogue and licence/source locks, runs Flutter analysis/tests, prepares generated/nested species assets and builds release artifacts.

The Google Play compliance branch builds an Android App Bundle and verifies the **built AAB** rather than assuming source assets were packaged. The verified release configuration uses application ID `nl.natuurgids.gerards_paddestoelen_wegwijzer`, Android minimum SDK 24, target SDK 36 or newer and currently only the `INTERNET` permission. The verifier also confirms valid bundle structure, all expected 7,483 species images and selected release-safety conditions.

A successful CI artifact is a store-submission candidate; Play Console signing, declarations, listing configuration and review remain external steps.

## Safety and provenance

Never consume a mushroom solely because of an app determination; edible specimens should be verified by a qualified local expert.

Conservation/Red List status must not be presented as legal-protection status unless a separate authoritative legal source establishes that protection.

Never expose raw coordinates for vulnerable/sensitive species, reconstruct precision hidden by a source or make source-provided locations more precise. Preserve provenance and consultation/access dates.

## Documentation

- `docs/functional-description.md` — complete functional/product description.
- `docs/technical-description.md` — implementation, storage, package, commerce and release mechanics.
- `docs/architectural-description.md` — module boundaries, trust boundaries, dependencies and multi-product architecture.
- `docs/product-roadmap.md` — product direction and sequencing.
- `docs/learning-commerce-contract.md` — paid-learning commerce/verification contract.
- `docs/learning-package-installer-contract.md` — package installation contract.
- `docs/learning-package-publishing.md` — package publishing process.
- `docs/learning-hosting-verifier-requirements.md` — protected hosting/verifier requirements.
- `docs/reference-data-plan.md` — reference-data direction.
