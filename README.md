# Gerards Paddestoelen Wegwijzer

Offline-first Flutter application for mushroom identification and mycology education.

## Core requirements

- Flutter mobile app.
- Offline-first: identification, species pages and training work without a network connection.
- SQLite database with normalized data and indexes for fast local filtering/search.
- Supported languages: Dutch (`nl`), English (`en`), German (`de`).
- Mushroom identification by observable traits.
- Educational lessons and questions with local progress tracking.
- Permanent mushroom safety disclaimer at the bottom of relevant screens.

## Database design

The SQLite schema is created in `lib/src/data/app_database.dart` and separates:

- taxonomy (`taxon`, `species`)
- translations (`species_text`)
- identification properties (`trait`, `trait_option`, `trait_option_text`, `species_trait`)
- species gallery metadata (`species_image`)
- training content (`lesson`, `lesson_text`, `question`, `question_text`, `answer_option`, `answer_option_text`)
- user learning state (`training_progress`)

Important filter and lookup columns are indexed, including taxonomy parents, scientific/common names, species traits, image order and lesson/question relations.

## Adding species pictures

Keep image bytes as compressed asset files rather than SQLite BLOBs. SQLite stores the asset path and metadata.

1. Add the pictures under `assets/images/species/<species-slug>/`.
2. Aim for about five useful identification perspectives per species:
   - cap/top
   - underside (gills, pores or teeth)
   - full side view / stem
   - stem base / volva or other diagnostic structure
   - habitat or another diagnostic detail
3. Add a row to `species_image` for every image, setting `species_id`, `asset_path`, `sort_order`, `angle_code`, and optionally photographer/license information.
4. Use `is_primary = 1` for the preferred cover picture.

The UI presents the images as a swipeable gallery. If an expected picture cannot be loaded, a standard **Image not available yet** placeholder is displayed automatically instead of a broken image.

For production content, image import tooling should generate thumbnails and validate that every database asset path exists before packaging the app.

## Safety

Identification output is educational assistance, not an edibility guarantee. Relevant screens always retain a visible safety warning telling users never to consume a mushroom solely because of an app identification and to have edible specimens verified by a qualified local expert.
