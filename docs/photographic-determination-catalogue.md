# Photographic determination in the main application

The main app's Identify screen defaults to concentric photographic selectors.
The outer ring previews the current observation's choices; the inner ring
previews all observation groups. The fixed pointer selects the top item.
Confirmation records a choice. Opening another group or rotating does not
record it. Existing independent observations and the list overview, dimensions,
regional season controls, safety notice and species detail navigation remain.
The original standalone determination wheel's branching engine is unchanged.

## Catalogue contract

`assets/data/identification_traits.json` is the canonical vocabulary. It contains
23 active groups with 341 choices in Dutch, English and German. The two legacy
ecology groups and their nine choices remain stored, inactive, to preserve
foreign keys and old observations. Thus SQLite stores 25 groups / 350 choices;
the app exposes 23 / 341. IDs 1–139 and all original relations are retained.
The standalone package carries a byte-identical copy, validated by CI.

The supplied visual reference claims 341 states but does not enumerate their
names (its printed group totals add to 235). This release therefore contains an
explicit, application-authored expansion of the reference, not a purported
transcription of unseen source material. Terminology was checked against
Michael Kuo's MushroomExpert glossary and major-group key:
https://www.mushroomexpert.com/glossary.html
https://www.mushroomexpert.com/major_groups.html

Photographs are teaching illustrations, never species evidence. Exact existing
state examples retain their mappings. New fine variants may share a broader
group photograph; `image_scope` records `state_example`, `group_example` or
`context_only`, and the wheel explains this. Smell and taste cannot be inferred
from a photograph. Taste choices record existing field notes, not a tasting
instruction. The new microscope photograph is an AI-generated observation
context, with its production prompt recorded under
`determination_wheel/assets/interface/ASSET_PROVENANCE.json`.

## Netherlands scope and evidence

Final results must link to the bundled Dutch Species Register checklist,
published through GBIF by Naturalis:
https://www.gbif.org/dataset/4dd32523-a3a3-43b7-84df-4cda02f15cf7
This is checklist membership, not a verified observation location, an occurrence
record, or morphology evidence. Checklist source record IDs are not mislabelled
as GBIF taxon keys.

Curated binomials are linked to checklist species-rank names after stripping
authorship. Exact unique binomials only: no genus-level, fuzzy or synonym
inference. Results retain the curated species detail ID and the Dutch checklist
species and source-record IDs. Duplicate checklist identities are suppressed.

104 additional factual trait links were individually reviewed against the
Identification guide sections of First Nature's existing 16 species pages on
2026-10-10. Each new link records its URL, section and review date in
`species_traits_europe.json`. This brings recorded relations to 231. Alternatives
explicitly cover described age-dependent colours. The original 127 mappings
remain. These links do not add any inferred mappings to checklist-only taxa.

Unknown traits and states with no recorded mappings contribute neither a
match nor a disagreement and do not dilute the score. Candidates expose
matched, evaluated, unknown and recorded-disagreement counts. The results panel
shows how many of the 12,509 Dutch checklist species have data for selected
traits and how many are unassessed. Only 16 species currently have morphology
mappings. The other species require source-backed character data; their names
or GBIF membership alone cannot identify a specimen. Scores represent agreement
with recorded data, not probabilities or edibility decisions.

SQLite v10 adds active-group and group-order metadata. Bundled content revision
8 / core dataset version 2 imports the expanded vocabulary for existing installs.
The main APK workflow analyzes and tests the main app, builds and validates the
packaged SQLite database, renders five real Flutter layouts, and builds the
main app APK with all offline assets. This is separate from the legacy wheel APK.

The packaged catalogue also restores 118 global IUCN conservation-status records
using the existing exact-name GBIF/IUCN importer, retrieved on 2026-10-10.
These records do not provide morphology, national legal protection or edibility
evidence. Dutch checklist membership and morphology counts are unchanged.
