# Source-directed determination in the main app

The main Identify screen opens the photographic 23-group / 341-choice
observation wheel. Its multiple choices remain available within each group.
The separately labelled field-guide mode follows decision keys. That mode
does not rank trait profiles or require a `species_trait` record. A confirmed
alternative follows the exact next couplet, another key, or the source's named
endpoint. Rotation only previews. The inner circle reviews the recorded path;
opening an earlier step discards its later answers and result. Switching to the
23-group / 341-choice observation view preserves the route. Reset clears both.

The bundled graph contains 1,066 questions from the user-supplied Veldgids I
(37 numbered keys) and Veldgids II (the form-group key and keys 1–10), plus the
app's two-way guide selector. Each choice retains all compound conditions,
source identity, PDF page number, and an illustrative context photograph. The
full alternatives are scrollable and also available together in a review sheet.
Source conditions remain in Dutch; surrounding controls support NL/EN/DE.

There are 754 distinct species-name endpoints. 752 names have an exact match
in the bundled Dutch Species Register checklist distributed through GBIF;
runtime requires a unique species-rank binomial match. No fuzzy or guessed
synonym matching is used. Two source names are intentionally not replaced:
Seifertia azaleae (II, PDF 28) and the printed Geastrum schmidelii (II, PDF 33).
A linked result opens the existing species detail page and shows its national
source record ID. Checklist membership is not proof of morphology or an
occurrence. Endpoints reflect the conditions the user selected, not a match
percentage or a guarantee.

Group names, sensu-lato complexes, unresolved names and microscopy or further
examination endpoints are not upgraded to species. Veldgids I's printed
Russula branch 37a (PDF page 10) stops after “Bij” and has no destination. This
is represented explicitly as a source gap, rather than inferring a species from
a similar preceding branch. Veldgids II's key 11 is a substrate reference list,
which expressly cannot determine a species by substrate alone, so it is not
turned into an artificial decision route. The other attached course documents
provide observation vocabulary and explanation; they are not independent
species keys. The Basisboek contains an overlapping alternative network and
has not been represented as if it were a third imported graph.

Explicit references to a later couplet are preserved (II 4/3a -> 5/11 and
II 10/35a -> 9/41). The source's “zie sleutel” redirects are followed. All nodes
are reachable, every destination exists, and every choice has a bundled image.
Images illustrate observation context; the full written conditions govern the
route. The observation vocabulary, database schema, original legacy branching
engine, field-measurement controls and species details remain available.

`tool/import_fieldguide_keys.py` extracts the first PDF by column, preserving
its page/couplet structure. `tool/source_review/fieldguide_ii_transcription.json`
contains the second guide's OCR transcription with source-checked numbering
repairs; `tool/compile_determination_keys.py` applies recorded italic-name OCR
corrections and compiles both graphs. PDF filenames and SHA-256 hashes are
recorded in the graph; the attached PDFs themselves are not committed. Rebuild
requires the exact user-supplied documents. `tool/validate_determination_keys.py`
and Flutter tests check the graph and route behavior. The main APK workflow
runs the validator, strict analysis, tests and release APK build.
