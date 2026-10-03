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

The current answer cards use schematic diagnostic symbols. These illustrations are explanatory UI aids, not determination evidence; any future diagnostic plate intended to carry evidential meaning must be purpose-made and reviewed. Useful illustration coverage includes:

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
