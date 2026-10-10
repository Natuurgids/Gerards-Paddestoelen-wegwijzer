# Paddenstoelen Determinatiewiel

A separate Flutter application inside the Gerards-Paddestoelen-wegwijzer repository.

## Current architecture

The determination model contains 24 source-coded observation markers, grouped in the phone UI into five functional wheels. Determination is branching rather than a forced 24-question sequence: each answer moves to the next relevant observation and records the route. The first encoded paths cover the source-supported general-key concepts: fruitbody form, hymenium/underside, cap surface, gill attachment, velum, hygrophanous character, spore colour, pore-bearing forms, bruising/colour change, stem surface, ecology and look-alike checking.

The result is deliberately possibility-first: observations narrow the set of still-compatible groups, but the app does not turn a match score into a probability of identification. Hard source criteria may exclude a group; source wording such as "vaak", "meestal" or "soms" is additional, non-exclusive evidence only and never excludes a possibility. This additional evidence is used only after hard match percentage and hard evidence when otherwise equal candidates are ordered.

Unknown observations neither support nor contradict a candidate. A 100% match therefore means only that every assessed, source-coded hard trait for that candidate matched; it does not mean 100% certainty. Coverage is shown separately from match percentage so a sparse source profile cannot masquerade as a well-supported identification.

Terminal routes that are not yet supported to species level explicitly request a genus/detail key, microscopy, chemistry or DNA as appropriate instead of inventing a species. Multiple unresolved species are a valid endpoint when the supplied source does not support a reliable distinction.

## Mobile determination instrument

On phones, the mushroom itself is the determination instrument rather than decoration. The cap shows the current observation/live outcome and contains exactly five functional spots. The stem contains the same five determination wheels:

1. Bouw
2. Kenmerken
3. Ecologie
4. Aanvullend
5. Mogelijkheden

A wheel only exposes observations that have actually been reached on the current branching route; **Mogelijkheden** remains available as a live view throughout. Reopening an earlier observation and selecting it truncates downstream answers so stale route state cannot survive a revision.

The pop-out selector follows a deliberate interaction boundary: **swipe left/right → centre an observation → explicitly select that observation → choose a characteristic**. Merely centring or dismissing an observation never mutates the determination. Answer choices are shown underneath as illustrated cards after the observation has been explicitly selected.

The five cap spots and five stacked stem discs are two controls for the same route state. Unreached wheels cannot be used to jump ahead. Completion means that a wheel has recorded an answer on the active route; the fifth wheel is complete only at the actual terminal state. Earlier observations remain revisitable.

The supplied app icon and splash artwork under `assets/` are product artwork and should be preserved exactly rather than regenerated during UI styling.

## Illustrations

All wheel and detail-key choices now have bundled photographic examples. Unknown, unmeasured and confirmation choices use field-notebook imagery, with a question badge for unassessed observations. The images are illustrative examples, not independent determination evidence. The current answer cards use photographic examples. These illustrations are explanatory UI aids, not determination evidence; any future diagnostic plate intended to carry evidential meaning must be purpose-made and reviewed. Useful illustration coverage includes:

- fruitbody forms
- gills / pores / teeth / folds
- cap surfaces
- free / attached / decurrent gills
- ring and volva forms
- hygrophanous cap
- spore-print colour classes
- bolete bruising reactions
- reticulate / scabrous / smooth stems
- substrate and host-tree/ecology cues

## Run

```bash
cd determination_wheel
flutter pub get
flutter run
```

## Safety

This app is an identification aid, not an edibility guarantee. A candidate identification must be independently confirmed. Some groups require microscopic characters and must be allowed to terminate as such rather than being forced to a species name.


## Result semantics

The intended flow is **observations → possible groups → possible genera → possible species → additional evidence needed → confirmation**. A result may legitimately end with several possibilities. Named species are shown only when the supplied source names them; a source statement such as “5 species” is not expanded into invented names.

Candidate ordering is deterministic rather than probabilistic: hard-trait match percentage first, then the number of matching hard traits, then additional non-exclusive evidence only as a tie-break. Coverage is displayed separately and never changes the ranking.

## Android beta build

The repository's **Flutter CI** workflow tests and analyzes this nested application, generates its Android platform scaffolding and launcher icon from the supplied artwork, builds a release APK, and uploads the artifact named `paddenstoelen-determinatiewiel-android-apk`. The dedicated **Determination wheel APK** workflow analyzes, tests, checks exhaustive image coverage, renders phone/small-phone/large-text/tablet/landscape screenshots, and builds this nested app independently of catalogue enrichment. Download that artifact from a **successful Determination wheel APK workflow run** on GitHub Actions, extract the ZIP, and install `app-release.apk` on an Android device. This APK is the determination wheel; the separate root-app AAB artifact is **not** this application.

The APK is currently a **field-testing beta**, not a validated species identification or edibility product. During device testing, check cap-spot and stem-disc reachability, swipe/centre/explicit-select behavior, reopening earlier observations, recalculation after changed answers, the live possibilities view, text scaling, screen-reader labels, and the exact safety warning on results. Record the device/Android version and the full observation route for any defect. Unknown answers must not exclude or positively support candidates.

The generated platform scaffolding and CI signing configuration are not a production release-signing plan. Before distribution beyond testers, establish a stable Android application ID, persistent signing credentials, versioning, privacy disclosures where applicable, and an actual device acceptance pass. Do not claim species-level coverage until source-backed detail criteria have been reviewed and encoded.

## Photographic interface

The supplied design references inform the woodland backdrop, real photographic mushroom instrument, five textured cream stem rings, gold active state, and cream photographic choice cards. The supplied app icon and splash artwork remain byte-for-byte unchanged. `assets/interface/ASSET_PROVENANCE.json` records the prompts and illustrative role of the newly generated production assets; `lib/photographic_assets.dart` maps every encoded wheel and detail-key choice. Existing legacy diagnostic artwork remains available but is no longer the choice-card fallback.

Run `python3 tool/validate_photographic_assets.py`, `flutter analyze --fatal-infos`, and `flutter test`. `test/interface_render_test.dart` saves actual Flutter screenshots under `build/interface-verification/`; CI uploads those for visual inspection. The APK archive also contains `COMMIT.txt` and `SHA256SUMS.txt`.
