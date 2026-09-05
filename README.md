# Gerards Paddestoelen Wegwijzer

Offline-first Flutter application for mushroom identification and mycology education.

## Product scope

This application is a **determination and education tool**. Observation registration, occurrence mapping, route tracking, or public observation storage are not product goals for the current development phase.

## Later improvements

- **Fieldora / Aperture alignment — deferred.** At a much later stage, review whether shared UX patterns, terminology, architecture, or integrations with the `Natuurgids/Fieldora` and `Natuurgids/Aperture` projects are useful. This is explicitly not part of the current roadmap and must not displace determination quality, educational content, catalogue quality, source provenance, offline reliability, localization, or mushroom safety work.

## Implemented

- Flutter mobile application foundation.
- Offline SQLite database; no network is needed for species browsing, identification or training.
- Dutch (`nl`), English (`en`) and German (`de`) content foundation.
- Developer-editable species/taxonomy, identification-trait, field-data, gallery and training manifests synchronized into SQLite.
- Normalized taxonomy, translated species content, localized identification traits, measurements, region-tagged seasonality, image metadata, lessons/questions and training progress.
- Indexed scientific/common-name lookup, localized trait lookup, species-trait filtering, numeric measurement lookup, regional month/season lookup, image ordering and lesson/question joins.
- Offline species catalogue with local search.
- Trait-based identification with weighted candidate ranking using one aggregate morphology query plus one optional field-evidence query.
- Optional determination evidence: cap diameter, stem height, stem diameter and explicitly selected regional month.
- Region choices and explanatory notes are loaded dynamically from `field_data.json`; Flutter UI code does not hard-code GB/IE, NL or DE choices.
- Species detail pages backed by SQLite, including measurements and region-labelled fruiting season.
- About five swipeable image slots per species, with automatic placeholder fallback when an image is not packaged yet.
- Offline lessons and quizzes with best score and attempt count persisted locally.
- Permanent mushroom safety disclaimer at the bottom of every current user-facing screen.
- Database repositories accept an injectable database provider for in-memory SQL testing while defaulting to the production singleton.
- Serialized first database open prevents concurrent startup reads from opening/synchronizing SQLite more than once.
- SQLite query-plan regression tests protect the main catalogue and identification indexes.
- GitHub Actions quality workflow running `flutter analyze` and `flutter test`.

## Run on Windows

Prerequisite: install Flutter and make sure `flutter doctor` succeeds.

From PowerShell in the repository root:

```powershell
.\tool\bootstrap.ps1
flutter run
```

The bootstrap script generates standard Android/iOS Flutter platform scaffolding, downloads dependencies, runs the analyzer and runs the test suite. Platform scaffolding is generated rather than hand-maintained during this early application phase.

## Database design

Schema creation and migrations live in `lib/src/data/database_schema.dart`; `lib/src/data/app_database.dart` owns opening, configuration and manifest synchronization. Developer-editable manifests are synchronized into SQLite whenever the database opens.

The normalized model separates:

- taxonomy: `taxon`, `species`
- species translations: `species_text`
- identification: `trait`, `trait_text`, `trait_option`, `trait_option_text`, `species_trait`
- quantitative field characters: `species_measurement`
- fruiting season with regional provenance: `species_season`, keyed by `(species_id, region_code, month)`
- galleries: `species_image`
- education: `lesson`, `lesson_text`, `question`, `question_text`, `answer_option`, `answer_option_text`
- user learning state: `training_progress`

Important lookup columns are indexed, including taxonomy parents, scientific/common names, translated trait labels, species traits, measurement ranges, regional season months, gallery order and training relations. Foreign keys are enabled, SQLite runs in WAL mode, and a 5-second busy timeout reduces transient lock failures.

`AppDatabase` shares one in-flight opening future. Concurrent first reads therefore await the same database open/import operation instead of racing multiple opens.

Repository classes in `lib/src/data/repositories.dart` take an optional `DatabaseProvider`. Normal application code uses `AppDatabase.instance.database`; tests can inject an in-memory database and exercise the same SQL without accessing a device database.

## Content manifests

The application keeps content maintenance separate from Flutter UI source code:

- `assets/data/species_catalog.json` — taxonomy, species metadata and NL/EN/DE species text.
- `assets/data/identification_traits.json` — localized determination traits/options and weighted species mappings.
- `assets/data/field_data.json` — localized `season_regions`, normalized numeric measurements and one or more `season_datasets` per species, each with its own `region_code`.
- `assets/data/species_images.json` — gallery paths, angle/order, primary image and optional attribution/licence metadata.
- `assets/data/training_content.json` — multilingual lessons, questions, answers and explanations.

Importers validate their manifest structure before applying writes. Catalogue and trait imports reject invalid IDs, translations and references before mutation; field and gallery imports validate their complete authoritative datasets before replacement; training content validates before insert/update and deliberately does not delete lessons, so persisted `training_progress` is never removed as a side effect of content synchronization.

Stable numeric IDs should not be reused for a different biological or educational meaning after release.

## Adding a species

1. Add the required genus/species taxonomy rows to `assets/data/species_catalog.json` using stable numeric IDs.
2. Add the species record and complete localized text objects where curated content is available.
3. Add identifying trait relations in `assets/data/identification_traits.json`.
4. Add cap/stem measurements and any validated regional calendars in `assets/data/field_data.json`.
5. Add gallery slots in `assets/data/species_images.json` when appropriately licensed media are available.

The import order is catalogue → traits → field data → images → training, so dependent manifests can safely reference newly added species. Manifest synchronization is dependency-aware: if catalogue synchronization fails, catalogue-dependent trait, field-data and gallery steps are skipped while independent training content can still synchronize.

`edible_status` and `toxicity_level` are descriptive metadata only. Neither contributes to identification confidence.

## Identification traits

Each developer-managed trait contains a stable id/code, structural category, NL/EN/DE label and one or more localized options. `species_traits` maps species to applicable options and provides a positive diagnostic weight.

The determination vocabulary includes cap colour/shape/surface, hymenium type, gill attachment, ring, volva, stem-base shape, bruising response, substrate, spore-print colour and broad habitat tree group. Trait coverage is curated and must not be presented as complete determination coverage for the full catalogue.

## Measurements and seasonality

`assets/data/field_data.json` stores quantitative data separately from prose. Each measurement has a machine-readable code, minimum, maximum and unit. Current examples include `cap_diameter`, `stem_height` and `stem_diameter`.

The manifest also declares `season_regions`. Each region has a stable code plus NL/EN/DE labels and explanatory notes. The determination screen discovers these options at runtime, so adding a validated Netherlands or Germany calendar does not require a Flutter UI change.

Fruiting periods are grouped into `season_datasets`. Each dataset has a `region_code` and individual month rows with likelihood 1–3. The same species may therefore have GB/IE, NL and DE calendars at the same time without one overwriting another.

## Adding species pictures

Keep compressed image files as application assets rather than SQLite BLOBs. SQLite stores paths and metadata, which keeps the database small and gallery queries fast.

1. Create a directory below `assets/images/species/`.
2. Aim for useful identification perspectives such as cap/top, underside, complete side/stem, stem base/volva, and habitat or another diagnostic detail.
3. Add entries to `assets/data/species_images.json` for the correct species ID.
4. Set `path`, `angle` and `order`; include photographer, licence and attribution metadata for external media.
5. Set `primary: true` on the preferred cover image.

Missing files never result in a broken UI: the application displays the localized **image not available yet** placeholder instead.

## Training content

`assets/data/training_content.json` defines lessons, localized lesson text, questions, answer choices and explanations. Developers can add training material without editing Dart source.

The training material teaches safe determination fundamentals and morphological concepts. Quiz progress, attempts and best score remain local in SQLite.

Single-choice questions must have exactly one correct answer. Both CI and runtime import validation enforce the training content contract before writes begin.

## Identification scoring

The identification screen stores selected observable trait options. Morphological candidates are scored from the normalized `species_trait` table using each relation's diagnostic weight in one indexed aggregate query.

Users may optionally add cap diameter, stem height, stem diameter and a month. Month evidence is only enabled after the user explicitly selects a regional season reference loaded from the manifest.

When at least one morphological trait is selected, morphology contributes **80%** of the combined ranking and optional field evidence contributes **20%**. If no morphology is selected, available field evidence may rank the catalogue by itself. Results expose morphology matches and field-data matches separately so the combined percentage is not mistaken for a direct identification probability.

The result score is a narrowing/ranking aid only. It is deliberately **not an edibility confidence score** and is not a statistical probability that a mushroom has been identified correctly.

## Tests

CI validates content contracts, database/import behavior, identification scoring and queries, localization, conservation provenance, source/licence locks, and the Flutter application tests before producing the Android release artifact.

## Safety

Identification output is educational assistance, not an edibility guarantee. Every current user-facing screen retains a visible warning telling users never to consume a mushroom solely because of an app identification and to have edible specimens verified by a qualified local expert.
