# Source snapshot review — 2026-10-01

This note records the evidence reviewed before accepting any new source snapshot.
It does **not** itself change `tool/source_snapshot_lock.json`.

## CI evidence

Flutter CI run 1669 generated `source-snapshot-drift.json` and
`source-identity-review.json` before the enforcement gate stopped the build.

Reviewed count drift from the 2026-09-08 baseline:

| Metric | Reviewed | Current | Delta |
| --- | ---: | ---: | ---: |
| Total species | 12,908 | 12,983 | +75 |
| NSR species | 12,892 | 12,967 | +75 |
| DGfM German names | 1,084 | 1,086 | +2 |
| UKSI English names | 12 | 12 | 0 |
| IUCN statuses | 118 | 118 | 0 |

The generated identity candidate contains 12,967 NSR identities and 1,086 DGfM
name identities.

## Upstream provenance check

### Nederlands Soortenregister (NSR)

Dataset: *Checklist Dutch Species Register - Nederlands Soortenregister*,
Naturalis Biodiversity Center, DOI 10.15468/rjdpzy.

GBIF reports publication date **2026-09-15** and metadata last modified
**2026-09-18**. Both are later than the reviewed 2026-09-08 snapshot. The
Darwin Core Archive endpoint remains the Naturalis NSR endpoint used by the
importer.

### DGfM

Dataset: *Taxon list of fungi and fungal-like organisms from Germany compiled
by the DGfM*, Staatliche Naturwissenschaftliche Sammlungen Bayerns,
DOI 10.15468/gtvmjw.

GBIF reports metadata last modified **2026-09-10**, also later than the
reviewed 2026-09-08 snapshot. The dataset remains licensed CC BY 4.0.

## Review decision

The observed drift is consistent with upstream datasets changing after the
reviewed baseline, rather than with the wheel implementation or CI test
changes. The lock must still not be advanced until the generated identity
candidate is committed as the reviewed identity baseline at the same time as
the new counts. This preserves exact identity drift detection for future
updates.

Evidence artifact: GitHub Actions run 1669, artifact `source-snapshot-drift`
(ID 11148093644).
