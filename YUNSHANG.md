# yunshang build (unofficial)

This repository is a **fork** of [immich-app/immich](https://github.com/immich-app/immich)
that publishes an unofficial Android build for personal use.

## What is different from upstream

1. **Places map initial location fix** — upstream hard-codes Honolulu
   (`21.44950, -157.91959`) for the Places card/page and `(0, 0) zoom 0` for the
   map view. This fork uses the device's last known location when the location
   permission has already been granted, and a neutral view otherwise.
2. **Separate application id** — `app.alextran.immich.yunshang`, so it can be
   installed next to the official Immich app. The launcher name is
   `Immich Yunshang`.
3. **In-app updates from this repository** — the app checks
   `releases/latest/download/latest.json`, compares `versionCode`, downloads the
   matching APK (with SHA-256 verification) and opens the system installer.
   Two settings under *Settings → Advanced* control this:
   - `启动时检查更新` (check on launch, default **on**)
   - `自动下载更新包` (auto download, default **off**)

   Android does not allow silent installs for normal apps, so the final
   confirmation is always shown by the system installer.

## Releases

Every upstream stable release is merged into `main` automatically, rebuilt and
published as `vX.Y.Z-yunshang.N`:

<https://github.com/whxciotw/immich-app/releases>

You can also use [Obtainium](https://github.com/ImranR98/Obtainium) to track this
repository's GitHub releases and install updates from there.

## Install

1. Allow "install unknown apps" for your browser / Obtainium / the app itself.
2. Install the APK. The official Immich app can stay installed.
3. Update later from inside the app, or from a newer release APK. Updates must
   be signed with the same key; the certificate SHA-256 is published in
   `yunshang/SIGNING_CERT_SHA256.txt` and in every release note.

## Signing

The release APKs are signed with a private key that is **not** in this
repository. The base64 keystore is stored in GitHub Actions secrets
(`ANDROID_KEYSTORE_B64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`,
`ANDROID_KEY_ALIAS`) and decoded only inside the build runner. Losing the key
means no further over-the-top updates are possible; leaking it allows forged
updates, so keep it offline and private.

## Automation

`.github/workflows/sync-and-build.yml` runs daily (and on demand):

1. finds the latest upstream stable tag (12h debounce, only published releases);
2. merges it into `main` (a conflict opens an issue and stops the run);
3. builds split + universal APKs with the upstream-pinned Flutter/JDK toolchain;
4. verifies the signature certificate and package/versionCode;
5. creates a GitHub release with the APKs, `latest.json` and `sha256sums.txt`.

## License

The upstream project is AGPL-3.0; this fork keeps the upstream `LICENSE` and
remains public. This is **not** an official Immich build.
