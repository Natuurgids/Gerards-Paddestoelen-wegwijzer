# Paid-learning hosting and verifier environment requirements

This document defines the production environment that must exist before paid learning can be enabled in Gerard's Paddestoelen Wegwijzer. It is an operational/deployment contract for the **protected learning-package host**, the **trusted purchase verifier/entitlement service**, and the authenticated session boundary shared by the app.

The current app is deliberately fail-closed. Store product configuration alone is not sufficient to enable commerce. Production must provide all required store mappings, authenticated session state, verifier endpoints, and protected content delivery before `LearningCommerceBootstrap` can become configured.

This document is provider-neutral. The implementation may run on a managed cloud, containers, serverless functions, or conventional infrastructure as long as the requirements below are met.

## 1. Required production components

A production deployment needs these logical components:

1. **Application session/account service** — authenticates the user/account and issues short-lived runtime credentials usable by both the verifier and paid-content host.
2. **Purchase verifier and entitlement service** — independently validates Google Play / App Store purchase evidence, owns the authoritative entitlement state, and returns only logical application entitlements to the app.
3. **Protected paid-learning content host** — serves `learning_package_catalog.json` and the package files produced by `tool/publish_learning_packages.py` only to an authenticated application session.
4. **Durable server-side datastore** — stores the account-to-entitlement relationship and the minimum transaction/audit state needed to make verification, restore, refund and revocation handling idempotent.
5. **Secret store** — holds provider credentials and signing/service secrets on the server side only.
6. **Monitoring, audit and backup facilities** — provide operational visibility and recoverability without logging raw receipts, session tokens, or paid lesson bodies unnecessarily.

The verifier and content host may be deployed in one environment or as separate services. The app contract still requires each endpoint group described below to obey its own same-origin rules.

## 2. Network and TLS requirements

All app-facing production endpoints **MUST** use HTTPS with a publicly trusted certificate and a hostname intended for production. Plain HTTP is not supported. URLs must not contain user credentials or fragments.

The verifier endpoints configured through `LEARNING_PURCHASE_VERIFY_URL` and `LEARNING_ENTITLEMENTS_URL` **MUST share exactly one HTTPS origin** (scheme, host, and effective port). The app refuses a verifier configuration that splits these endpoints across origins.

The paid-learning catalogue configured through `LEARNING_PACKAGE_CATALOG_URL` and every `packages/...` path referenced by that catalogue **MUST share exactly one HTTPS origin**. The app resolves package paths relative to the catalogue and rejects cross-origin package URLs.

The verifier origin and paid-content origin do **not** have to be the same origin as each other. They may be separate services. Both receive credentials from the same runtime session-header provider, so each service must validate the same application identity/session model or an intentionally equivalent credential scoped to that service.

App-facing endpoints **MUST NOT rely on HTTP redirects**. The production clients deliberately refuse redirects so authentication headers and purchase evidence cannot be forwarded to another host. Deploy the final canonical endpoint directly.

TLS termination may occur at a trusted reverse proxy/load balancer, but traffic from that boundary to private application services must remain inside a controlled network. Prefer encrypted internal transport where the platform supports it. Certificate renewal must be automatic or operationally monitored so expiry cannot silently disable purchases/restores/downloads.

## 3. Authentication and session requirements

The app supplies authentication/session headers at runtime. The environment must therefore provide an account/session mechanism that can issue and refresh credentials without embedding a reusable backend secret in the APK.

Required properties:

- credentials are user/session scoped, not a shared application master secret;
- credentials can expire and rotate; the app requests headers again for every verifier and package request;
- the server validates expiry, issuer/audience or equivalent scope, and account identity on every request;
- logout/account revocation can invalidate future verifier and content requests;
- authentication failure returns an explicit non-2xx response rather than a redirect to a login page;
- session tokens, refresh tokens, store credentials, private keys, database passwords, and provider API credentials are never placed in Dart defines, source control, generated package catalogues, lesson packages, analytics events, or public logs.

The paid-content host must not treat possession of the catalogue URL as authorization. The catalogue itself is fetched through the authenticated transport in production.

## 4. Trusted purchase verifier API

The verifier is a security boundary. It **MUST NOT trust the client merely because the client reports a purchase**. It must independently validate the supplied store evidence with the relevant Google Play or App Store verification mechanism and map the verified provider product to the app's logical product/entitlement pair.

Both current verifier operations are JSON `POST` requests and use `contract_version: 1`.

### 4.1 Purchase verification endpoint

Configured as `LEARNING_PURCHASE_VERIFY_URL`.

Request body:

```json
{
  "contract_version": 1,
  "provider": "google_play | app_store",
  "product_key": "logical_product_key",
  "transaction_id": "provider transaction id or null",
  "verification_payload": "store server-verification payload"
}
```

A successful 2xx response must be a JSON object:

```json
{
  "product_key": "logical_product_key",
  "entitlement_key": "logical_entitlement_key",
  "active": true
}
```

Verifier behavior must satisfy all of the following:

- reject unauthenticated/expired sessions;
- reject unknown logical products and provider product identifiers;
- verify the store evidence independently and fail closed on provider/API ambiguity;
- ensure the verified provider product belongs to the expected app/package/bundle and environment;
- ensure the verified provider product maps to the request's logical `product_key`;
- derive `entitlement_key` from trusted server configuration, never from an untrusted client field;
- handle repeated/redelivered purchase evidence idempotently;
- persist the entitlement result before returning an active entitlement;
- support inactive/revoked state when authoritative store state establishes refund, revocation, cancellation, chargeback, or other loss of permanent access;
- never grant an entitlement from `transaction_id` alone; the app may legitimately send it as null;
- never return a different product/entitlement pair to “repair” a client request. Mismatches are errors.

The app will independently compare the returned logical product and entitlement against its bundled offering catalogue. A mismatch is rejected and the store transaction is not completed through the verified path.

### 4.2 Entitlement reconciliation endpoint

Configured as `LEARNING_ENTITLEMENTS_URL` on the same origin as the verification endpoint.

Request body:

```json
{
  "contract_version": 1
}
```

A successful 2xx response must be a JSON object:

```json
{
  "active_entitlements": [
    "learning.specialist.example"
  ]
}
```

This endpoint must return the **complete authoritative active entitlement snapshot for the authenticated account**, not only changes since the previous call. The app replaces its local verified-entitlement namespace from this snapshot during reconciliation. Missing entitlements are therefore interpreted as no longer active.

The service must be able to reconstruct this snapshot from durable server state and/or authoritative store state after a device reinstall or sign-in on another device. Local device cache is not the source of truth.

### 4.3 Response and error behavior

Verifier responses must remain small: the current app refuses responses above **64 KiB**. Keep success responses compact and do not return receipts, provider API responses, stack traces, secrets, or large diagnostics to the client.

Use normal non-2xx status codes for authentication, authorization, malformed evidence, provider verification failure, rate limiting, and server failure. Do not convert failures into `200` with an `active: true` fallback. Do not redirect error responses.

The client currently applies a finite approximately **15-second network timeout**. The verifier should normally respond much faster; external store calls need bounded timeouts/retries so a provider outage cannot exhaust server resources.

## 5. Server-side entitlement model

The server must maintain a provider-neutral entitlement model. Store identifiers are inputs to verification, not the keys used by learning content.

At minimum, durable state should be able to answer:

- which authenticated account owns which logical entitlement;
- which store/provider and provider product established that entitlement;
- enough stable provider transaction/original-purchase identity to make processing idempotent;
- whether the entitlement is active or revoked;
- when verification/reconciliation last established the state;
- an audit reason/source for state changes without storing more receipt data than necessary.

The seven logical `product_key` → `entitlement_key` bindings must match `assets/data/learning_offerings.json`. Provider-specific Google Play/App Store IDs must be configured server-side consistently with the app's deployment mapping. Store price is not part of the entitlement model and must not be invented by the backend; display pricing remains store-authoritative in the app.

Permanent learning unlocks must remain permanent unless authoritative provider/account state establishes that access is no longer valid. Do not make access depend on a short content-download token once the package is already validly installed; the app intentionally supports offline use from its durable verified entitlement cache.

## 6. Store-provider integration requirements

The verifier environment needs outbound HTTPS access to the official store verification services required by the chosen Google Play and/or App Store implementation. Provider credentials must live only in the server-side secret store with least privilege and rotation procedures.

The implementation must distinguish production from test/sandbox purchase evidence and must not allow sandbox/test transactions to create production entitlements. Product identifiers, application/package identifiers, and provider environment must all be checked as part of verification.

Refund/revocation handling must not rely solely on the original purchase call. The production design must have a way to learn authoritative state changes later, for example during reconciliation and/or through provider server notifications. Notification handlers, if used, must themselves verify provider authenticity and process events idempotently.

Do not acknowledge/complete a store transaction merely because the backend endpoint was called. The mobile app completes the retained store transaction only after trusted verification succeeds **and** the verified entitlement has been durably persisted locally. The backend's responsibility is to return a trustworthy entitlement result.

## 7. Protected paid-learning content host

The content host serves the output of `tool/publish_learning_packages.py` from a separately controlled production location. Commercial lesson bodies must never be published to this public Git repository. The prototype specialist payloads already present in Git history are considered compromised prototype material and must not be reused as protected commercial content.

Expected release layout:

```text
<protected-origin>/learning_package_catalog.json
<protected-origin>/packages/boletes-pores.json
<protected-origin>/packages/gilled-mushrooms.json
<protected-origin>/packages/amanitas-dangerous-lookalikes.json
<protected-origin>/packages/russulas-milkcaps.json
<protected-origin>/packages/bracket-fungi-wood-decay.json
<protected-origin>/packages/small-brown-mushrooms.json
<protected-origin>/packages/field-microscopy-spores.json
```

Hosting requirements:

- require a valid application session for the catalogue and every package file;
- return package/catalogue bytes directly with HTTP 200; do not redirect to object-storage/CDN signed URLs on another origin;
- if object storage or a CDN is used, expose it through the same authenticated origin (for example a reverse proxy/private origin) so the app's no-redirect/same-origin contract remains valid;
- never make the storage bucket/container publicly listable or anonymously readable;
- publish the catalogue and its referenced package files as one release so the catalogue never points at missing or half-uploaded content;
- preserve the exact package bytes emitted by the publisher. Reformatting, recompressing, newline conversion, templating, or mutation after publication will break the catalogue SHA-256/size checks;
- serve `learning_package_catalog.json` below **256 KiB**; the app enforces that catalogue limit;
- package responses must not exceed their catalogue-declared `package_size_bytes`; the app also requires the received byte count to equal that value exactly;
- use sensible `Content-Type` such as `application/json`; do not transform JSON at the edge;
- disable intermediary behavior that rewrites response bodies;
- protect unpublished/private source material separately from published release artifacts.

The app validates SHA-256 and exact size before parsing/importing a package. Authentication controls who may fetch; SHA-256 controls integrity. Neither replaces the other.

## 8. Authorization for paid downloads

The current app performs its own entitlement check before requesting a package, but the server must not treat that client-side check as a security boundary.

For strongest protection, the paid-content host should authorize package requests against the authenticated account's server-side entitlement state. The catalogue may list all available paid packages for the authenticated user, but an individual `packages/<package>.json` request should be denied unless the account owns the corresponding logical entitlement.

If the content host and verifier use separate services, entitlement authorization must use a trusted server-to-server source/cache or signed internal claim. Do not ask the mobile client to present a self-asserted entitlement key as proof of ownership.

## 9. Data protection and privacy

The commerce/verifier environment should collect only data needed for authentication, purchase verification, entitlement restoration, fraud/abuse prevention, support, and legally required accounting/audit functions.

Mandatory handling rules:

- do not log `Authorization` headers, refresh tokens, raw verification payloads, provider credentials, private keys, or full paid lesson bodies;
- redact secrets and purchase evidence from structured logs, traces, exception reporting, and request dumps;
- encrypt sensitive data at rest using the hosting platform's managed encryption and encrypt backups;
- restrict production database, object storage, logs, and secret-store access by least privilege;
- separate production from development/test data and credentials;
- define retention/deletion rules for purchase evidence and account data instead of retaining raw receipts indefinitely;
- document subprocessors/hosting regions and meet applicable privacy/data-protection obligations for the production audience;
- provide a controlled operational process for account deletion while retaining only records that must legally or technically remain.

This paid-learning backend does not need mushroom observation coordinates or sensitive-species location data. Do not send or store observation/location data in the commerce, verifier, entitlement, or paid-content hosting system.

## 10. Availability, rate limiting and abuse resistance

The environment must fail closed without making the free/offline product unusable. A verifier or hosting outage may temporarily prevent purchase verification, restore, or new package downloads, but it must not corrupt existing local training progress or make the built-in free lessons dependent on the backend.

Production services should provide:

- per-account/IP/device-aware rate limiting appropriate to authentication and purchase verification;
- request/body size limits before expensive parsing/provider calls;
- bounded outbound provider timeouts and retry with backoff for transient failures;
- idempotency for repeated store evidence and provider notifications;
- health/readiness checks that do not expose secrets or entitlement data;
- capacity for restore/reconciliation bursts after releases or outages;
- protection against brute-force session/token attempts and obvious automated abuse.

Do not cache authenticated verifier responses in a shared/public cache. Paid package files may use private caching only when cache keys and authorization prevent one account/session from receiving another account's protected response.

## 11. Deployment, release and rollback

Use separate development/test and production environments. Production configuration and secrets must not be copied into CI fixtures or this public repository.

Recommended release sequence:

1. create newly authored private package sources outside this repository;
2. run `tool/publish_learning_packages.py` and retain the immutable release output;
3. deploy all package files to a staging/private release location;
4. verify exact bytes/hashes/sizes and authenticated access;
5. publish the matching catalogue atomically at the configured catalogue path;
6. verify the verifier endpoints, entitlement reconciliation, package authorization, and store sandbox/test flow in a non-production environment;
7. configure production store product IDs/endpoints in the release build only after production services are ready;
8. run an end-to-end production-readiness check before enabling Buy/Restore.

Do not overwrite an already published package version with different bytes. Publish a higher `content_version` for content changes. Keep a last-known-good release available for operational recovery. Rollback must never silently make the app accept an older package over a newer installed version; the client intentionally prevents automatic downgrade.

Database migrations and backend contract changes must be backward-compatible with app versions still in circulation. Introduce a new `contract_version` only with an explicit compatibility plan.

## 12. Observability and audit

Monitor at least authentication failures, verifier success/failure rates, store-provider latency/errors, entitlement reconciliation failures, package 401/403/404/5xx rates, catalogue/package integrity deployment checks, and unusual verification/download volume.

Alerts must identify the operation and correlation/request ID without including raw receipt payloads or credentials. Audit records should make it possible to explain why an entitlement became active/inactive and which verified provider event caused the transition.

Operational dashboards should distinguish store-provider outages from verifier failures and content-host failures. A store outage should not be misdiagnosed as content corruption, and a content-host outage should not change entitlement ownership.

## 13. Backup and disaster recovery

Back up the authoritative entitlement datastore and the private paid-learning release artifacts. Backups must be encrypted and access controlled. Recovery procedures must be tested periodically.

A fresh verifier deployment must be able to reconstruct an account's active entitlement snapshot without relying on a particular device's SQLite cache. A restored content host must reproduce the exact published bytes for each active catalogue version so installed/update integrity checks remain deterministic.

Define recovery objectives appropriate to the commercial service. The architecture does not require the free determination/catalogue experience to wait for backend recovery, but purchase verification, restore, and new paid downloads should have an explicit operational recovery target.

## 14. Production configuration consumed by the app

The release build/runtime ultimately needs:

| Configuration | Purpose | Requirement |
| --- | --- | --- |
| `LEARNING_GOOGLE_PLAY_PRODUCT_IDS` | Logical product → Google Play product mapping | Complete/unique mapping for all bundled paid offerings when Android commerce is enabled |
| `LEARNING_APP_STORE_PRODUCT_IDS` | Logical product → App Store product mapping | Complete/unique mapping for all bundled paid offerings when iOS commerce is enabled |
| `LEARNING_PURCHASE_VERIFY_URL` | Purchase verification endpoint | HTTPS; same origin as entitlements endpoint; no redirect |
| `LEARNING_ENTITLEMENTS_URL` | Full active-entitlement reconciliation endpoint | HTTPS; same origin as verification endpoint; no redirect |
| `LEARNING_PACKAGE_CATALOG_URL` | Protected package catalogue | HTTPS; package files remain on this origin; no redirect |
| runtime session-header provider | Authenticates verifier and protected delivery calls | Short-lived/rotatable account session; never a compiled reusable backend secret |

Endpoint URLs and provider product mappings are public deployment configuration. Authentication credentials and provider/server secrets are not.

## 15. Minimum production-readiness acceptance checklist

Do not enable paid learning until all of these are true:

- [ ] A real account/session flow supplies rotatable runtime authentication headers.
- [ ] Verifier and entitlement endpoints are deployed on one stable HTTPS origin with no redirects.
- [ ] The verifier independently validates both supported store providers that are enabled for release.
- [ ] Product/application/environment binding is checked server-side; sandbox cannot grant production access.
- [ ] Entitlement state is durable, provider-neutral, idempotent, and supports inactive/revoked state.
- [ ] Restore returns the complete active entitlement snapshot for the authenticated account.
- [ ] Refund/revocation changes can reach or be discovered by the entitlement service.
- [ ] Provider credentials are stored in a managed server-side secret store with least privilege.
- [ ] Newly authored commercial package revisions have been built outside the public repository.
- [ ] The catalogue and all seven package files are deployed on one protected HTTPS origin.
- [ ] Catalogue and package endpoints require authentication; individual package requests are server-authorized by entitlement.
- [ ] Hosting returns direct 200 responses without cross-origin redirects or body transformations.
- [ ] Published bytes exactly match publisher-generated SHA-256 and size metadata.
- [ ] Logs/traces redact session credentials and store verification payloads.
- [ ] Production data, secrets, and paid lesson bodies are absent from this public repository and CI fixtures.
- [ ] Monitoring, rate limiting, backups, recovery, and entitlement audit trails are operational.
- [ ] End-to-end purchase → trusted verification → entitlement persistence → store completion → authenticated package download → offline reopen has been tested.
- [ ] Restore on a second/fresh device reproduces the same active entitlement set and permits redownload.
- [ ] A verifier/content-host outage leaves built-in free learning and already-installed offline content usable.

Until this checklist is satisfied, production should remain in the current fail-closed state with Buy/Restore and new paid downloads disabled.

## Related repository contracts

- `docs/learning-commerce-contract.md` — client commerce, verifier, entitlement cache, runtime, and bootstrap contract.
- `docs/learning-package-installer-contract.md` — downloadable package validation/import and protected-delivery rules.
- `docs/learning-package-publishing.md` — private-source publisher and immutable hosting artifact layout.
- `assets/data/learning_offerings.json` — public logical identities for the seven paid offerings.
