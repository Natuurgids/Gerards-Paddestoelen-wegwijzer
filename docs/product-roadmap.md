# Product roadmap

## Current product scope

Gerards Paddestoelen Wegwijzer is a paid standalone mushroom field guide, determination aid and mycology education product. The core product is intended to remain useful offline and independent of optional learning commerce or future AI services.

Current priorities are:

- determination quality and curated determination coverage;
- high-quality reference media with source/licence attribution;
- broad, reliable offline catalogue coverage;
- expandable lessons, quizzes and training pathways;
- catalogue, taxonomy and source quality;
- Dutch-first localization with English and German support;
- permanent mushroom-consumption safety guidance;
- reproducible Android/Windows release packaging and artifact-level verification.

The app is not currently an observation-registration or occurrence-mapping product.

## Shared engineering, separate compiled products

The codebase should evolve toward reusable field-guide infrastructure, but biological domains are selected at build/product time.

Future mushrooms, trees, birds or other guides are separate compiled applications with their own application identity, branding, catalogue, domain-specific traits, media and education catalogue. They are not downloadable domain plugins inside one universal app.

Reusable infrastructure can include navigation, localisation, SQLite/data access, image/provenance handling, education, package installation, entitlement/commerce boundaries and release tooling. Domain-specific biological behaviour should remain in the relevant compiled product rather than being generalized without a concrete reuse need.

See `docs/architectural-description.md`.

## Education model

Education is modular relative to the core field guide.

### Bundled/free learning

- packaged offline introductory lessons and quizzes;
- safe determination fundamentals;
- morphology and field-character training;
- local progress, attempts and best scores;
- free additional activities/packages where useful, including printable/colouring material;
- no commerce dependency for free learning.

### Optional paid learning packages

Additional specialist content can include:

- advanced determination modules;
- family- and genus-level courses;
- lookalike comparison modules;
- microscopy and spore-character training;
- structured exam/training tracks;
- additional premium quizzes and learning pathways.

Paid learning remains an expansion of the current compiled product. It does not turn the app into a marketplace for other biological domains.

Logical entitlements remain separate from lesson/package content and from the payment provider. The package installer asks whether the required entitlement is granted; it does not parse provider receipts or implement payment rules.

## Commerce architecture

Keep three concerns separate:

1. **Content** — lessons, questions, explanations, activities and package metadata.
2. **Entitlements** — verified logical access to a paid package.
3. **Commerce** — a replaceable purchase/provider adapter plus trusted verification.

The repository currently includes a concrete mobile-store adapter path behind provider-neutral interfaces. Production commerce remains fail-closed until real provider product mappings, trusted verification, authenticated runtime state and protected package hosting are configured.

The architecture must not embed reusable merchant/backend credentials in the compiled app. A future compliant commerce route can replace the concrete adapter without rewriting education or package semantics, provided it produces the same trusted logical entitlement contract.

See `docs/learning-commerce-contract.md` and `docs/architectural-description.md`.

## AI: separate experiment, not a core dependency

AI is not a current core feature and should not be required for catalogue browsing, deterministic determination or installed education.

If tested later:

1. introduce a small provider-neutral AI service interface;
2. test with an external provider under explicit limits;
3. measure usefulness, reliability, privacy implications and operating cost;
4. only then decide whether to continue, price it separately or host inference on owned hardware;
5. preserve the ability to disable/remove AI without changing the field guide or education architecture.

AI credentials and privileged infrastructure must remain outside the APK/AAB.

## Deferred Aperture integration

Observation/location infrastructure may remain as a future integration boundary for Aperture. This is intentionally deferred and must not drive the current user experience.

Any future integration must preserve the privacy boundary: never expose or reconstruct more precise sensitive-species location data than the upstream source makes public.

## Release readiness

The Android Google Play compliance path now builds an AAB and verifies the produced artifact. The current branch checks application identity, platform floor, expected permissions, AAB structure, packaged species images and selected release-security conditions after Flutter analysis/tests.

A green repository workflow establishes build/repository readiness only. Store-side signing, declarations, listing configuration and review remain external release steps.

## Near-term sequence

1. Keep the mushroom core stable, offline and well-sourced.
2. Continue improving curated determination coverage and reference media.
3. Preserve reproducible release verification for Android and Windows.
4. Complete real protected hosting/verifier deployment before enabling paid learning commerce.
5. Add learning packages independently of the core application release where the package contract supports it.
6. Use the shared/product-configuration boundary when a second compiled nature-guide product is actually started.
7. Test AI only after the core and learning-package model are proven.

## Documentation map

- `docs/functional-description.md` — user-visible behaviour and product scope.
- `docs/technical-description.md` — implementation technologies, data, build and security mechanics.
- `docs/architectural-description.md` — module boundaries, dependencies, trust boundaries and multi-product direction.
- `docs/learning-commerce-contract.md` — commerce/verification/entitlement contract.
- `docs/learning-package-installer-contract.md` — learning-package installation boundary.
- `docs/learning-package-publishing.md` — package publishing process.
- `docs/learning-hosting-verifier-requirements.md` — external hosting/verifier requirements.
- `docs/reference-data-plan.md` — reference-data direction.
