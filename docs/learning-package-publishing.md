# Private paid-learning publishing

Commercial paid-learning lesson bodies must not be committed to this public repository. The public repository contains only the seven safe offering identities/titles/summaries in `assets/data/learning_offerings.json` plus the app/runtime/publishing code.

`tool/publish_learning_packages.py` turns a private source directory into deployment artifacts for separately controlled hosting. By default it requires exactly the seven current public offerings.

## Private source layout

Keep the source directory outside the repository checkout. It must contain exactly one JSON file for every public `package_key`:

```text
/private/paid-learning-v2/
  boletes-pores.json
  gilled-mushrooms.json
  amanitas-dangerous-lookalikes.json
  russulas-milkcaps.json
  bracket-fungi-wood-decay.json
  small-brown-mushrooms.json
  field-microscopy-spores.json
```

Each file is the app's `DownloadableLearningPackage` payload: `package_version: 1`, a positive `content_version`, matching course/product/entitlement identity, downloadable modules, and `training_content` version 2. Store price/currency is forbidden anywhere in these payloads.

The publisher validates package/course identity against the public offering catalog, module/lesson ownership, unique lesson/question/answer identifiers, NL/EN/DE lesson/question/answer text, and exactly one correct answer per question. Public catalog titles, summaries and sort order are derived from `learning_offerings.json`; private source files do not redefine them.

## Build

Choose an output directory outside this repository as well:

```bash
python3 tool/publish_learning_packages.py \
  --source-dir /private/paid-learning-v2 \
  --output-dir /private/paid-learning-release-v2
```

The tool deliberately refuses source or output paths inside this public repository. It also refuses to overwrite an existing output directory.

A successful build is atomic and contains:

```text
/private/paid-learning-release-v2/
  learning_package_catalog.json
  packages/
    boletes-pores.json
    gilled-mushrooms.json
    amanitas-dangerous-lookalikes.json
    russulas-milkcaps.json
    bracket-fungi-wood-decay.json
    small-brown-mushrooms.json
    field-microscopy-spores.json
```

Package JSON is canonicalized deterministically before publishing. The catalog's `package_size_bytes` and `package_sha256` are calculated from those exact emitted bytes. Deploy the catalog and `packages/` directory together to the same protected HTTPS origin configured as `LEARNING_PACKAGE_CATALOG_URL`.

## Deployment boundary

The publisher performs validation and integrity packaging; it is not a hosting or authentication system. The controlled host must still require the authenticated application session used by `AuthenticatedLearningPackageByteSource`. Do not put a reusable hosting/verifier secret in source, Dart defines, the APK, generated catalog, or package files.

The old prototype specialist payloads that remain reachable in Git history are not valid commercial source material. Commercial releases must use newly authored private revisions.

CI runs `tool/test_publish_learning_packages.py` with generated private-style fixtures for all seven current offerings. CI never contains the real commercial lesson bodies.
