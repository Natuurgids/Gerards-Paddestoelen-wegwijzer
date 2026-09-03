# Gerards Paddestoelen Wegwijzer

Offline-first Flutter application for mushroom identification and mycology education.

## Implemented

- Flutter mobile application foundation.
- Offline SQLite database; no network is needed for species browsing, identification or training.
- Dutch (`nl`), English (`en`) and German (`de`) content foundation.
- Developer-editable species/taxonomy, identification-trait, field-data, gallery and training manifests synchronized into SQLite.
- Normalized taxonomy, translated species content, localized identification traits, measurements, region-tagged seasonality, image metadata, lessons/questions and training progress.
- Indexed scientific/common-name lookup, localized trait lookup, species-trait filtering, numeric measurement lookup, regional month/season lookup, image ordering and lesson/question joins.
- Offline species catalogue with local search.
- Trait-based identification with weighted candidate ranking using one aggregate morphology query plus one optional field-evidence query.
- Optional observation evidence: cap diameter, stem height, stem diameter and explicitly selected regional observation month.
- Species detail pages backed by SQLite, including measurements and region-labelled fruiting season.
- About five swipeable image slots per species, with automatic placeholder fallback when an image is not packaged yet.
- Offline lessons and quizzes with best score and attempt count persisted locally.
- Permanent mushroom safety disclaimer at the bottom of relevant screens.
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

The schema is in `lib/src/data/app_database.dart`. The app is currently schema version 5. Developer-editable manifests are synchronized into SQLite whenever the database opens.

The normalized model separates:

- taxonomy: `taxon`, `species`
- species translations: `species_text`
- identification: `trait`, `trait_text`, `trait_option`, `trait_option_text`, `species_trait`
- quantitative field characters: `species_measurement`
- fruiting season with regional provenance: `species_season`, keyed by `(species_id, region_code, month)`
- galleries: `species_image`
- education: `lesson`, `lesson_text`, `question`, `question_text`, `answer_option`, `answer_option_text`
- user learning state: `training_progress`

Important lookup columns are indexed, including taxonomy parents, scientific/common names, translated trait labels, species traits, measurement ranges, regional season months, gallery order and training relations. Foreign keys are enabled and SQLite runs in WAL mode.

## Content manifests

The application keeps content maintenance separate from Flutter UI source code:

- `assets/data/species_catalog.json` — taxonomy, species metadata and NL/EN/DE species text.
- `assets/data/identification_traits.json` — localized determination traits/options and weighted species mappings.
- `assets/data/field_data.json` — normalized numeric measurements and one or more `season_datasets` per species, each with its own `region_code`.
- `assets/data/species_images.json` — gallery paths, angle/order, primary image and optional attribution/licence metadata.
- `assets/data/training_content.json` — multilingual lessons, questions, answers and explanations.

Stable numeric IDs should not be reused for a different biological or educational meaning after release.

## Adding a species

1. Add the required genus/species taxonomy rows to `assets/data/species_catalog.json` using stable numeric IDs.
2. Add the species record and complete `nl`, `en` and `de` text objects.
3. Add identifying trait relations in `assets/data/identification_traits.json`.
4. Add cap/stem measurements and any validated regional calendars in `assets/data/field_data.json`.
5. Add about five gallery slots in `assets/data/species_images.json`.

The import order is catalogue → traits → field data → images → training, so dependent manifests can safely reference newly added species.

`edible_status` and `toxicity_level` are descriptive metadata only. Neither contributes to identification confidence.

## Identification traits

Each developer-managed trait contains a stable id/code, structural category, NL/EN/DE label and one or more localized options. `species_traits` maps species to applicable options and provides a positive diagnostic weight.

The current starter vocabulary includes cap colour/shape/surface, hymenium type, gill attachment, ring, volva, stem-base shape, bruising response, substrate, spore-print colour and broad habitat tree group.

## Measurements and seasonality

`assets/data/field_data.json` stores quantitative data separately from prose. Each measurement has a machine-readable code, minimum, maximum and unit. Current examples include `cap_diameter`, `stem_height` and `stem_diameter`.

Fruiting periods are grouped into `season_datasets`. Each dataset has a `region_code` and individual month rows with likelihood 1–3. The same species may therefore have GB/IE, NL and DE calendars at the same time without one overwriting another. The starter season records currently use `GB-IE`, and both the species screen and identification form label that regional reference explicitly.

Schema v5 migrates the previous single-region key to `(species_id, region_code, month)`. The importer still accepts the old `season_region` + `season` shape for backward compatibility, but new content should use `season_datasets`.

## Adding species pictures

Keep compressed image files as application assets rather than SQLite BLOBs. SQLite stores paths and metadata, which keeps the database small and gallery queries fast.

1. Create a directory below `assets/images/species/`.
2. Aim for five useful identification perspectives:
   - cap/top
   - underside: gills, pores or teeth
   - complete side view/stem
   - stem base, volva or another diagnostic structure
   - habitat or another important detail
3. Add entries to `assets/data/species_images.json` for the correct species ID.
4. Set `path`, `angle` and `order`; optionally add `photographer`, `license` and `thumbnailPath`.
5. Set `primary: true` on the preferred cover image.

Missing files never result in a broken UI: the application displays the localized **image not available yet** placeholder instead.

## Training content

`assets/data/training_content.json` defines lessons, localized lesson text, questions, answer choices and explanations. Developers can add training material without editing Dart source.

The current starter material includes safe-identification fundamentals and an underside/spore lesson. Quiz progress, attempts and best score remain local in SQLite.

Single-choice questions must have exactly one correct answer. CI verifies this content contract.

## Identification scoring

The identification screen stores selected observable trait options. Morphological candidates are scored from the normalized `species_trait` table using each relation's diagnostic weight in one indexed aggregate query.

Users may optionally add cap diameter, stem height, stem diameter and an observation month. Month evidence is only enabled after the user explicitly selects a regional season reference. The current starter calendar is `GB-IE`; it is never silently applied to Dutch or German observations.

When at least one morphological trait is selected, morphology contributes **80%** of the combined ranking and optional field evidence contributes **20%**. If no morphology is selected, available field evidence may rank the catalogue by itself. Results expose morphology matches and field-data matches separately so the combined percentage is not mistaken for a direct identification probability.

The weighting and field-match rules are implemented in pure helper functions in `lib/src/data/identification_scoring.dart` and covered by unit tests. Field evidence is evaluated in one additional SQLite query using indexed measurement and regional season tables, rather than querying once per species.

The result score is a narrowing/ranking aid only. It is deliberately **not an edibility confidence score** and is not a statistical probability that a mushroom has been identified correctly.

## Tests

`test/content_manifest_test.dart` validates the developer-editable content contracts, including:

- unique taxonomy/species IDs and valid taxon references
- complete Dutch, English and German species text
- unique trait and option IDs with all three translations
- valid species-trait references and positive weights
- valid measurement ranges and units
- unique region codes per species, unique months within each regional calendar, month range 1–12 and likelihood range 1–3
- five ordered image slots and exactly one primary image per seeded species
- complete multilingual training text
- globally unique question/answer IDs and exactly one correct answer per single-choice question

`test/identification_scoring_test.dart` verifies morphology dominance, field-only ranking behavior, score clamping, inclusive measurement ranges and exact regional season matching.

CI runs both analysis and tests on pushes to the feature/main branches and on pull requests to `main`.

## Safety

Identification output is educational assistance, not an edibility guarantee. Relevant screens retain a visible warning telling users never to consume a mushroom solely because of an app identification and to have edible specimens verified by a qualified local expert.
