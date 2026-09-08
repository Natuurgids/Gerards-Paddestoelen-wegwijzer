# Functional description

## Purpose

Gerards Paddestoelen Wegwijzer is an offline-first mushroom field guide, determination aid and mycology learning application. The product is intended to help users browse a broad fungal catalogue, narrow possible identifications from observable characteristics, inspect reference images and source information, and learn through lessons and quizzes.

The application is a determination and education tool. It is not an edibility guarantee, medical/safety authority, observation-registration system or occurrence-mapping product.

## Product model

The repository is the mushroom product built on reusable application infrastructure. Future nature-guide products such as trees or birds are intended to be separately compiled applications using shared engineering, not downloadable biological domains inside this app.

Each compiled product owns its own:

- application identity and branding;
- biological catalogue and media;
- domain-specific traits and field data;
- educational catalogue;
- release/store configuration.

Users therefore install the mushroom app as a complete mushroom product. A future bird or tree product would be a separate app.

## Core user functions

### Species catalogue

Users can browse and search the packaged fungal catalogue offline. Scientific and available common names are searchable. Species detail pages expose the locally available descriptive, taxonomic, measurement, seasonality, conservation/provenance and gallery information.

The packaged catalogue currently contains 12,525 species. Catalogue presence does not imply that every species has complete determination traits, translations or reference imagery.

### Offline reference images

Reference images are packaged with the release where available. The current verified Android release contains 7,483 species images. Image source, creator/author and licence/attribution metadata are displayed when supplied by the reviewed source data.

### Determination

Users select observable mushroom characteristics. The application ranks candidate species using curated weighted morphology relations. Optional field evidence can include cap diameter, stem height, stem diameter and an explicitly selected regional month/season reference.

The ranking is an educational narrowing aid, not a probability of correct identification and never an edibility confidence score.

### Species detail

Species pages combine available local catalogue data, images, measurements, regional fruiting information and source/provenance information. All core browsing and packaged reference use is designed to work without a network connection.

### Education

The app supports offline lessons and quizzes. Quiz progress, attempts and best scores are stored locally.

Education is intentionally modular relative to the core field guide. The product can contain:

- bundled/free lessons;
- free additional packages such as activities or printable colouring material;
- optional paid specialist learning packages.

Additional learning packages are content expansions for this compiled mushroom product. They are not a mechanism for downloading another biological domain.

### Paid learning access

Paid learning is separated into content, entitlement and commerce concerns. The learning renderer does not decide how payment occurred. It asks whether the logical entitlement required by a package is available.

A purchase event alone is not sufficient to unlock content. The implemented commerce boundary requires trusted verification and durable entitlement persistence before paid access is granted. Installed and verified entitled content can remain usable offline.

The current repository contains provider-neutral commerce interfaces and a concrete mobile-store adapter path, but production commerce remains fail-closed until real product identifiers, trusted verification, authenticated runtime state and protected package hosting are configured.

### Package installation

Remote learning packages are treated as untrusted input until validated. Installation requires package metadata/integrity checks and, for paid packages, the required logical entitlement. Package installation is separate from payment processing.

### Localisation

The application foundation supports Dutch, English and German. Content availability can differ by species and source; missing translations must not be invented.

## Safety and privacy behaviour

A permanent mushroom-consumption warning is part of the product: users must never consume a mushroom solely because of an app determination and should have edible specimens verified by a qualified local expert.

Location/observation infrastructure is not a current user-facing product function. Any future integration must preserve source precision and must never expose or reconstruct more precise sensitive-species coordinates than the source makes public.

## Release behaviour

The application is built as a self-contained Flutter product. Core catalogue/reference functionality remains available offline. Network access is used only by explicitly configured update, commerce, verification or remote-package channels.

The Google Play compliance test branch builds an Android App Bundle with application ID `nl.natuurgids.gerards_paddestoelen_wegwijzer`, Android minimum SDK 24 and target SDK 36 or newer. The release verifier checks bundle structure, expected permissions, packaged species images and selected release-safety conditions before the artifact is uploaded by CI.

## Explicitly separate future capability

AI is not part of the core product dependency chain. If introduced, it should be an optional service behind a replaceable interface so an external provider can be tested first and a self-hosted service can replace it later. The field guide and installed learning content must continue to function without AI.

## Related documentation

- `docs/technical-description.md`
- `docs/architectural-description.md`
- `docs/product-roadmap.md`
- `docs/learning-commerce-contract.md`
- `docs/learning-package-installer-contract.md`
- `docs/learning-package-publishing.md`
- `docs/learning-hosting-verifier-requirements.md`
