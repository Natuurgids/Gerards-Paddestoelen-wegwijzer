# Paddenstoelen Determinatiewiel

A separate Flutter application inside the Gerards-Paddestoelen-wegwijzer repository.

## Current architecture

The UI is a 24-marker wheel, but determination is branching rather than a forced 24-question sequence. Each observation moves to the next relevant marker and records the route. The first encoded paths cover the source-supported general-key concepts: fruitbody form, hymenium/underside, cap surface, gill attachment, velum, hygrophanous character, spore colour, pore-bearing forms, bruising/colour change, stem surface, ecology and look-alike checking.

Terminal routes that are not yet supported to species level explicitly request a genus/detail key or microscopy instead of inventing a species.

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
