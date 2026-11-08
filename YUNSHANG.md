# yunshang build (unofficial)

This repository is a **fork** of [immich-app/immich](https://github.com/immich-app/immich)
that publishes an unofficial Android build for personal use.

## What is different from upstream

1. **Places map initial location fix** — upstream hard-codes Honolulu
   (`21.44950, -157.91959`) for the Places card/page and `(0, 0) zoom 0` for the
   map view. This fork uses the device's last known location when the location
   permission has already been granted; without it, it falls back to the
   5%-95% bounding box of the user's geotagged photos, and only uses a neutral
   view when there are no geotagged assets at all.
2. **Separate application id** — `app.alextran.immich.yunshang`, so it can be
   installed next to the official Immich app. The launcher name is `Immich`.
3. **Places page hierarchy** — the Places list is a collapsible
   country → province → city tree (countries expanded by default), with
   asset counts, name sorting, a search box that flattens the results and an
   expand/collapse-all button in the app bar.
4. **People management** — merge up to five people, hide/show a person, show
   hidden people, multi-select people and bulk hide/show, plus quick actions
   for hiding all/unnamed people (the album cover picker was removed because
   the existing "set as album cover" action already covers that).
6. **Timeline grouping** — 年 / 月 / 日 segmented control on the Photos page
   and in Settings → Photo Grid → Group by (both write the same setting).
7. **Adaptive grid** — on by default: 9/5/3 columns for year/month/day at
   390dp, scaling with screen width (foldables get more columns, no cap).
   With adaptive mode, pinch cycles 年 ↔ 月 ↔ 日; with it off, pinch changes
   the 2–6 column count as before.
8. **Grouping pill** — custom 36dp floating capsule above the bottom tabs;
   translucent (40% / selected 68%), becomes more transparent while
   scrolling (16% / 38%) and restores ~600ms after scrolling stops.
9. **In-app updates from this repository** — the app checks
   `releases/latest/download/latest.json`, compares `versionCode`, downloads the
   matching APK (with SHA-256 verification) and opens the system installer.
   Settings under *Settings → Advanced*:
   - `启动时检查更新` (check on every cold start and after >30 min in background,
  default **on**)
   - `自动下载更新包` (auto download, default **off**)
   - `立即检查更新` (manual check; bypasses the switch/throttle/ignored version)

   Split APKs built by Flutter carry an ABI-specific `versionCode`
   (`universal` is the base, `armeabi-v7a` +1000, `arm64-v8a` +2000,
   `x86_64` +4000). `latest.json` publishes the code per asset and the app
   compares against the asset matching the device ABI.

Release APKs are signed with **v1 + v2 + v3** schemes for compatibility with
older/OEM package installers (MIUI/HyperOS included).

   Android does not allow silent installs for normal apps, so the final
   confirmation is always shown by the system installer.

## Releases

Every upstream stable release is merged into `main` automatically, rebuilt and
published as `vX.Y.Z-yunshang.N`:

<https://github.com/whxciotw/immich-app/releases>

Current stable build: **v3.3.6-yunshang.8** (upstream `v3.3.6`).
Test channel build: **v3.3.6-yunshang-test.4** (GitHub Pre-release, not served to stable users).

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


## Test channel (pre-releases)

The test channel is a GitHub **Pre-release** and is never served by the stable
`releases/latest` endpoint. Stable users stay on `-yunshang.N` releases.

- Build: `Actions → Build test APK (pre-release) → Run workflow`
  (`base_version` defaults to `3.3.6`).
- APK: the workflow creates a tag like `v3.3.6-yunshang-test.1` and uploads
  APKs, checksums and `latest.json` there.
- Pointer: a fixed `test-latest` pre-release holds the current
  `latest.json` at
  `https://github.com/whxciotw/immich-app/releases/download/test-latest/latest.json`.
- The test APK is compiled with `--dart-define=YUNSHANG_TEST_CHANNEL=true`, so
  only test builds read the test channel. Stable builds keep reading
  `releases/latest`.
- Test version codes use `base_code * 100 + 100 + N`; they are above the
  current stable build and increment only within the test channel.
- To test in-app auto update, install `test.N`, then run the test workflow
  again to publish `test.N+1`; the installed test build should prompt on next
  launch.
- To go back to stable, install the current stable APK manually (a higher test
  versionCode means Android will not offer an automatic "downgrade").
- Builds include `YunshangUpdater` logs (switch, channel, current/remote
  versions, ignored version, dialog failures) visible in Settings → Logs.
