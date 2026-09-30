# Paddenstoelen Determinatiewiel

A separate Flutter application inside the Gerards-Paddestoelen-wegwijzer repository.

## Current architecture

The UI is a 24-marker wheel, but determination is branching rather than a forced 24-question sequence. Each observation moves to the next relevant marker and records the route. The first encoded paths cover the source-supported general-key concepts: fruitbody form, hymenium/underside, cap surface, gill attachment, velum, hygrophanous character, spore colour, pore-bearing forms, bruising/colour change, stem surface, ecology and look-alike checking.

The result is deliberately possibility-first: observations narrow the set of still-compatible groups, but the app does not turn a match score into a probability of identification. Hard source criteria may exclude a group; source wording such as "vaak", "meestal" or "soms" is supporting/typical evidence only and never excludes a possibility. Typical evidence is used only after hard match percentage and hard evidence when otherwise equal candidates are ordered.

Unknown observations neither support nor contradict a candidate. Coverage is shown separately from match percentage so a sparse source profile cannot masquerade as a well-supported identification.

Terminal routes that are not yet supported to species level explicitly request a genus/detail key, microscopy, chemistry or DNA as appropriate instead of inventing a species. Multiple unresolved species are a valid endpoint when the supplied source does not support a reliable distinction.

## Illustrations

The current prototype uses schematic symbols only. Diagnostic illustrations should be purpose-made and reviewed before they are used as evidence in the key. Planned plates include:

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
