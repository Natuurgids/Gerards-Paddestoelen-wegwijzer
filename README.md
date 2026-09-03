# Gerards Paddestoelen Wegwijzer

Offline-first Flutter application for mushroom identification and mycology education.

## Implemented

- Flutter mobile application foundation.
- Offline SQLite database; no network is needed for species browsing, identification or training.
- Dutch (`nl`), English (`en`) and German (`de`) content foundation.
- Developer-editable species/taxonomy, identification-trait and gallery manifests synchronized into SQLite.
- Normalized taxonomy, translated species content, localized identification traits, image metadata, lessons/questions and training progress.
- Indexed scientific/common-name lookup, localized trait lookup, species-trait filtering, image ordering and lesson/question joins.
- Offline species catalogue with local search.
- Trait-based identification with weighted candidate ranking using one aggregate SQLite query.
- Species detail pages backed by SQLite.
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

The schema is in `lib/src/data/app_database.dart`. Initial offline training content is seeded by `lib/src/data/database_seeder.dart`. Species/taxonomy, identification traits and galleries are developer-editable manifests synchronized into SQLite when the database opens.

The normalized model separates:

- taxonomy: `taxon`, `species`
- species translations: `species_text`
- identification: `trait`, `trait_text`, `trait_option`, `trait_option_text`, `species_trait`
- galleries: `species_image`
- education: `lesson`, `lesson_text`, `question`, `question_text`, `answer_option`, `answer_option_text`
- user learning state: `training_progress`

Important lookup columns are indexed, including taxonomy parents, scientific/common names, translated trait labels, species traits, gallery order and training relations. Foreign keys are enabled and SQLite runs in WAL mode.

## Adding a species

The developer-editable catalogue is `assets/data/species_catalog.json`.

1. Add the required genus/species taxonomy rows under `taxa` using stable numeric IDs.
2. Add the species record under `species` and reference its `taxon_id`.
3. Supply `edible_status` and `toxicity_level` as descriptive metadata only; neither is used as an identification-confidence value.
4. Add complete `nl`, `en` and `de` text objects with common name, summary, description, habitat and lookalikes.
5. Add identifying trait relations in `assets/data/identification_traits.json`.
6. Add about five gallery slots in `assets/data/species_images.json`.

The importer upserts catalogue records before traits and images, so those manifests can safely reference newly added species. Keep released IDs stable so progress, references and future migrations remain predictable.

## Adding or changing identification traits

The developer-editable identification manifest is `assets/data/identification_traits.json`. The application synchronizes it into the normalized identification tables whenever the database opens.

Each trait contains:

- a stable numeric `id`
- a stable machine-readable `code`
- a structural `category`
- localized `labels` for `nl`, `en` and `de`
- one or more options with their own stable ids/codes/order/localized labels

The `species_traits` section maps a species to the option that applies and assigns a positive `weight`. Higher weights make diagnostically useful observations count more strongly in candidate ranking.

Keep IDs stable once released. Changing the displayed wording is safe; reusing an ID for another biological meaning is not. The content tests verify unique IDs, required translations, valid references and positive weights.

The current starter vocabulary includes cap colour/shape/surface, hymenium type, gill attachment, ring, volva, stem-base shape, bruising response, substrate, spore-print colour and broad habitat tree group. It is intentionally extensible for more detailed production keys.

## Adding species pictures

Keep compressed image files as application assets rather than SQLite BLOBs. SQLite stores paths and metadata, which keeps the database small and gallery queries fast.

The developer-editable gallery manifest is `assets/data/species_images.json`. It is synchronized into the normalized `species_image` table whenever the database opens, so developers can add or reorder photographs without editing Dart source code.

1. Create a directory such as `assets/images/species/amanita_muscaria/`.
2. Aim for five useful identification perspectives:
   - cap/top
   - underside: gills, pores or teeth
   - complete side view/stem
   - stem base, volva or another diagnostic structure
   - habitat or another important detail
3. Add the files to `assets/data/species_images.json` for the correct `speciesId`.
4. Set `path`, `angle` and `order`; optionally add `photographer`, `license` and `thumbnailPath`.
5. Set `primary: true` on the preferred cover image.
6. Ensure the image files remain under the `assets/images/` tree declared in `pubspec.yaml`.

The gallery reads images in `sort_order`. Missing files never result in a broken UI: the application displays the localized **image not available yet** placeholder instead. This means developers can add species records before all photography has been collected.

For a production catalogue, the next content tooling step is to move training seed data into a validated manifest and automatically generate thumbnails while checking that every declared asset exists and that photographer/licence fields are complete.

## Identification scoring

The identification screen stores the user’s selected observable trait option per trait. Candidate species are scored from the normalized `species_trait` table using each relation’s `weight`. Ranking is performed with one indexed aggregate query rather than a query for every species/trait pair.

Results display a percentage and number of matched selected traits. This score is a narrowing/ranking aid only. It is deliberately **not an edibility confidence score**.

## Tests

`test/content_manifest_test.dart` validates the developer-editable content contracts, including:

- unique taxonomy/species IDs and valid taxon references
- Dutch, English and German species text
- unique trait and option IDs
- Dutch, English and German trait/option labels
- valid species-trait references and positive weights
- five ordered image slots per seeded species
- exactly one primary image per seeded species

CI runs both analysis and tests on pushes to the feature/main branches and on pull requests to `main`.

## Safety

Identification output is educational assistance, not an edibility guarantee. Relevant screens retain a visible warning telling users never to consume a mushroom solely because of an app identification and to have edible specimens verified by a qualified local expert.
