# yunshang build (unofficial)

This repository is a **fork** of [immich-app/immich](https://github.com/immich-app/immich)
that publishes an unofficial Android build for personal use.

## What is different from upstream

1. **Places map initial location fix** — upstream hard-codes Honolulu
   (`21.44950, -157.91959`) for the Places card/page and `(0, 0) zoom 0` for the
   map view. This fork uses the device's last known location when the location
   permission has already been granted, and a neutral view otherwise.
2. **Separate application id** — `app.alextran.immich.yunshang`, so it can be
   installed next to the official Immich app. The launcher name is `Immich`.
3. **Places page hierarchy** — the Places list is a collapsible
   country → province → city tree (countries expanded by default), with
   asset counts, name sorting, a search box that flattens the results and an
   expand/collapse-all button in the app bar.
4. **In-app updates from this repository** — the app checks
   `releases/latest/download/latest.json`, compares `versionCode`, downloads the
   matching APK (with SHA-256 verification) and opens the system installer.
   Two settings under *Settings → Advanced* control this:
   - `启动时检查更新` (check on launch, default **on**)
   - `自动下载更新包` (auto download, default **off**)

   Split APKs built by Flutter carry an ABI-specific `versionCode`
   (`universal` is the base, `armeabi-v7a` +1000, `arm64-v8a` +2000,
   `x86_64` +4000). `latest.json` publishes the code per asset and the app
   compares against the asset matching the device ABI.

   Android does not allow silent installs for normal apps, so the final
   confirmation is always shown by the system installer.

## Releases

Every upstream stable release is merged into `main` automatically, rebuilt and
published as `vX.Y.Z-yunshang.N`:

<https://github.com/whxciotw/immich-app/releases>

Current build: **v3.3.6-yunshang.3** (upstream `v3.3.6`).

If the daily scheduled run does not happen (GitHub disables schedules in forks
until Actions is enabled for the fork), run it manually:
`Actions → Sync upstream and build APK → Run workflow`.

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

The keystore used for the first build was generated on the setup host under
`/root/workspace/Immich/keystore/`; download `yunshang-release.jks` and
`passwords.txt` and keep them offline before that directory is removed.


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
