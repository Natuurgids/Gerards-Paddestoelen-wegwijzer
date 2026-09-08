# Architectural description

## Architectural objective

The application is organized as a reusable field-guide platform with a mushroom-specific compiled product on top. Modularity is used to make components replaceable and reusable without turning biological domains into runtime downloadable plugins.

The governing rule is:

**shared engineering, separate compiled products, separate domain content.**

A future trees or birds product is compiled and released as another application. It may reuse the same framework, but users do not install a bird/tree domain into Gerards Paddestoelen Wegwijzer.

## Context

```text
User
  |
  v
Compiled Mushroom App
  |-- Catalogue / Search
  |-- Determination
  |-- Species Detail / Gallery
  |-- Education / Quiz
  |-- Optional Learning Packages
  `-- Settings / Local State

Optional external boundaries
  |-- reviewed reference-data sources (build/content pipeline)
  |-- commerce provider adapter
  |-- trusted purchase verifier
  |-- protected learning-package host
  `-- future optional AI service
```

The core catalogue and determination experience does not require those optional runtime services.

## Major architectural modules

### Product configuration

Defines compile-time/product-specific identity and domain choices: application ID, name/branding, catalogue assets, domain-specific traits and education catalogue.

This is the seam used to create another compiled nature-guide product without adding a runtime domain marketplace.

### Application shell

Owns Flutter application composition, navigation, localisation, theme/settings and dependency wiring. It depends on abstract services/repositories where external behaviour can vary.

### Reference-data module

Owns taxonomy, species text, field data, seasonality, conservation/provenance and galleries. Source manifests are developer/content inputs; SQLite is the normalized runtime representation.

### Determination module

Owns observable trait selection and candidate ranking. It consumes normalized biological data and returns educational ranking information. It has no commerce dependency.

### Education module

Owns lessons, questions, answers, explanations and local training progress. It can render bundled/free content and installed additional packages.

### Learning-package module

Owns remote package catalogue/install/update mechanics, validation, integrity and activation. It asks the entitlement boundary whether protected content may be installed/used; it does not verify payment receipts itself.

### Entitlement module

Represents logical access rights independently from a payment provider. Durable verified entitlement state is the single local source used by learning access and the package installer.

### Commerce module

Adapts a concrete purchase channel to logical learning products. Store/provider IDs and prices remain outside educational content. Purchase evidence has no authority until trusted verification succeeds.

The concrete provider can be replaced without changing lesson/package semantics, provided the replacement produces the same verified logical entitlement contract. This is the intended extension point for future compliant commerce choices.

### Trusted verifier boundary

Runs outside the mobile trust boundary. It validates provider purchase evidence and returns logical entitlement state. Secrets and privileged provider credentials remain outside the compiled app.

### Package hosting boundary

Hosts commercial learning bytes separately from the public source repository. Authorization controls who can fetch protected bytes; SHA-256/manifest checks independently protect integrity.

### AI boundary

AI, if ever enabled, is a separate optional service. It must not be required by catalogue browsing, deterministic ranking or installed education. The provider should be swappable so a third-party experiment can later be replaced by self-hosted inference.

## Dependency direction

```text
UI / Application shell
        |
        +--> Catalogue/Search --------> Reference repositories --> SQLite
        |
        +--> Determination -----------> Determination repository --> SQLite
        |
        +--> Education ---------------> Education repository ----> SQLite
        |        |
        |        `--> Package service --> Entitlement repository
        |                    |                 ^
        |                    v                 |
        |              Package byte source    |
        |                                      |
        `--> Commerce runtime --> Trusted verifier
                                  |
                                  `--> verified entitlement persistence
```

Important dependency constraints:

- determination never depends on commerce;
- lesson rendering never parses provider receipts;
- package installation never grants its own entitlement;
- provider-specific product IDs never become educational-content identifiers;
- the public app never contains reusable backend/merchant secrets;
- optional network services must not become prerequisites for core offline use.

## Trust boundaries

### Trusted local application state

Locally packaged manifests and database state are trusted only after repository/import validation. Installed remote packages become trusted for use only after their package contract and integrity checks pass.

### Untrusted remote input

Remote catalogues, package bytes, commerce callbacks and verifier responses are validated against explicit contracts. Redirects/origins/size limits are constrained by the transport layer where implemented.

### External authority

The mobile app is not the authority for payment validity. A trusted verifier/provider-confirmed server-side path establishes the entitlement. The device stores the resulting verified logical access state for offline use.

## Offline-first boundary

Core mushroom functionality is packaged into the application release:

```text
compiled app
  + SQLite schema/importers
  + species catalogue
  + determination data
  + field data
  + packaged reference images
  + bundled education
```

Network-dependent capabilities are additive:

```text
optional network
  + catalogue/reference updates
  + paid-learning purchase verification
  + additional learning-package delivery
  + future AI
```

Loss of network connectivity must not disable already packaged core data or already installed/verified content.

## Build and release architecture

```text
reviewed source/manifests
        |
        v
content generation + licence/source locks
        |
        v
Flutter analyze + tests
        |
        v
prepare nested species assets
        |
        v
build release artifact
        |
        v
artifact-level verifier
        |
        v
CI artifact / store submission candidate
```

Artifact verification is deliberately after the build so CI proves what was packaged, not merely what exists in the repository.

For the Android Play test path, the verifier checks application identity/platform floor, permissions, AAB structure, expected packaged images and selected release-security conditions.

## Future multi-product architecture

The preferred evolution is a shared framework plus compile-time product configuration, conceptually:

```text
shared framework
  |-- navigation/localisation
  |-- database infrastructure
  |-- package installer
  |-- education
  |-- commerce/entitlements
  |-- image/provenance handling
  `-- common release tooling

compiled products
  |-- Mushrooms: mushroom catalogue + traits + branding + courses
  |-- Trees: tree catalogue + traits + branding + courses
  `-- Birds: bird catalogue + traits + branding + courses
```

Do not generalize domain concepts merely for theoretical reuse. Extract interfaces when behaviour is genuinely shared; keep mushroom-specific biological rules in the mushroom product/domain implementation.

## Architecture decisions

1. Offline-first core over backend dependency.
2. SQLite normalized runtime model over UI parsing large manifests directly.
3. Content data separated from Flutter presentation source.
4. Provider-neutral logical entitlements over provider IDs in lesson content.
5. Trusted verification before durable paid access.
6. Integrity-checked package delivery separated from commerce.
7. Build-time biological product selection over runtime biological plugins.
8. AI as an optional replaceable service, never a core dependency.
9. Artifact-level release verification over source-tree assumptions.
10. Safety/provenance constraints are architectural invariants, not optional UI copy.

## Related documentation

- `docs/functional-description.md`
- `docs/technical-description.md`
- `docs/product-roadmap.md`
- `docs/learning-commerce-contract.md`
- `docs/learning-package-installer-contract.md`
- `docs/learning-package-publishing.md`
- `docs/learning-hosting-verifier-requirements.md`
