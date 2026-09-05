# Product roadmap

## Current product scope

Gerards Paddestoelen Wegwijzer is currently a mushroom determination and mycology education tool.

Current priorities are:

- determination quality and curated determination coverage;
- high-quality determination illustrations and species media;
- expandable lessons, quizzes and training pathways;
- catalogue, taxonomy and source quality;
- offline reliability;
- Dutch-first localization with English and German support;
- permanent mushroom-consumption safety guidance.

The app is not currently an observation-registration or occurrence-mapping product.

## Deferred Aperture integration

Observation/location infrastructure may remain in the codebase as a future integration boundary for Aperture. This is intentionally deferred and must not drive the current user experience or roadmap.

If Aperture integration is developed later, the existing privacy boundary remains mandatory: never expose or reconstruct more precise sensitive-species location data than the upstream source makes public.

## Learning model: free core and premium expansion

The learning architecture should support a free core plus optional paid education without making the current offline lessons dependent on a payment backend.

### Free core

- packaged offline introductory lessons and quizzes;
- safe determination fundamentals;
- basic morphology and field-character training;
- local progress, attempts and best scores;
- no account required for the basic learning path.

### Premium learning

Future premium content can include, for example:

- advanced determination modules;
- family- and genus-level courses;
- lookalike comparison modules;
- advanced microscopy and spore-character training;
- structured exam/training tracks;
- professional or institutional learning packs;
- additional premium quizzes and learning pathways.

Premium status should be represented as an entitlement, separate from lesson content and separate from the payment provider. Lesson records can later carry a stable access tier or entitlement key such as `free`, `premium`, or a named course entitlement.

The application should ask an entitlement service whether the current user may access a premium module. The lesson renderer itself should not contain payment-provider logic.

## Payment architecture

Do not hard-code one payment gateway into lesson manifests. Use three separate layers:

1. **Content** — lessons, questions, explanations and course metadata.
2. **Entitlements** — which account/device may access which premium course or tier.
3. **Commerce** — App Store / Google Play billing and, where platform rules permit, a future web payment portal.

This keeps the educational content portable and allows payment rules to change without rewriting the lesson system.

For store-distributed mobile apps, purchases that unlock digital lessons or premium app content must follow the applicable Apple App Store and Google Play billing rules. A web portal can still be used for account management, institutional sales, and other permitted purchase flows, while the entitlement backend remains the single source of truth for access.

## Not in the current implementation phase

The following are documented improvements, not current implementation work:

- Aperture observation/location integration;
- account system and cloud sync;
- payment portal;
- App Store / Google Play purchase integration;
- premium entitlement backend;
- institutional licensing and classroom administration;
- Fieldora/Aperture ecosystem alignment beyond clearly reusable future interfaces.

The current development focus remains determination and education quality.