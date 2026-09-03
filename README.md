# Gerards Paddestoelen Wegwijzer

Offline-first Flutter application for mushroom identification and mycology education.

## Implemented

- Flutter mobile application foundation.
- Offline SQLite database; no network is needed for species browsing, identification or training.
- Dutch (`nl`), English (`en`) and German (`de`) content foundation.
- Normalized taxonomy, translated species content, identification traits, image metadata, lessons/questions and training progress.
- Indexed scientific/common-name lookup, species-trait filtering, image ordering and lesson/question joins.
- Offline species catalogue with local search.
- Trait-based identification with weighted candidate ranking.
- Species detail pages backed by SQLite.
- About five swipeable image slots per species, with automatic placeholder fallback when an image is not packaged yet.
- Offline lessons and quizzes with best score and attempt count persisted locally.
- Permanent mushroom safety disclaimer at the bottom of relevant screens.
- GitHub Actions Flutter analyzer workflow.

## Run on Windows

Prerequisite: install Flutter and make sure `flutter doctor` succeeds.

From PowerShell in the repository root:

```powershell
.\tool\bootstrap.ps1
flutter run
```

The bootstrap script generates standard Android/iOS Flutter platform scaffolding, downloads dependencies and runs `flutter analyze`. Platform scaffolding is generated rather than hand-maintained during this early application phase.

## Database design

The schema is in `lib/src/data/app_database.dart`. Initial offline content is seeded by `lib/src/data/database_seeder.dart`.

The normalized model separates:

- taxonomy: `taxon`, `species`
- translations: `species_text`
- identification: `trait`, `trait_option`, `trait_option_text`, `species_trait`
- galleries: `species_image`
- education: `lesson`, `lesson_text`, `question`, `question_text`, `answer_option`, `answer_option_text`
- user learning state: `training_progress`

Important lookup columns are indexed, including taxonomy parents, scientific/common names, species traits, gallery order and training relations. Foreign keys are enabled and SQLite runs in WAL mode.

## Adding species pictures

Keep compressed image files as application assets rather than SQLite BLOBs. SQLite stores paths and metadata, which keeps the database small and gallery queries fast.

1. Create a directory such as `assets/images/species/amanita_muscaria/`.
2. Aim for five useful identification perspectives:
   - cap/top
   - underside: gills, pores or teeth
   - complete side view/stem
   - stem base, volva or another diagnostic structure
   - habitat or another important detail
3. Add image rows for that species in the content seed/import source with `asset_path`, `sort_order`, `angle_code`, and optionally `photographer`, `license` and `thumbnail_path`.
4. Mark the preferred cover image with `is_primary = 1`.
5. Ensure the directory remains under the `assets/images/` tree declared in `pubspec.yaml`.

The gallery reads images in `sort_order`. Missing files never result in a broken UI: the application displays the localized **image not available yet** placeholder instead. This means developers can add species records before all photography has been collected.

For a production catalogue, the next content tooling step should move the seed records into validated JSON/CSV import files and automatically generate thumbnails while checking that every declared asset exists and that photographer/licence fields are complete.

## Identification scoring

The identification screen stores the user’s selected observable trait option per trait. Candidate species are scored from the normalized `species_trait` table using each relation’s `weight`. Results display a percentage and number of matched selected traits.

This score is a narrowing/ranking aid only. It is deliberately **not an edibility confidence score**.

## Safety

Identification output is educational assistance, not an edibility guarantee. Relevant screens retain a visible warning telling users never to consume a mushroom solely because of an app identification and to have edible specimens verified by a qualified local expert.
