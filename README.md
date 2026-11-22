# Mystic GSI - GitHub Actions

Turn **OEM stock firmware into a flashable GSI** with GitHub Actions.

This repository is a **thin wrapper around [MysticGSI](https://github.com/MysticGSI/mysticgsi)** — the actual converter. It does not reimplement firmware extraction, patching, or image generation. Each run clones MysticGSI at a pinned ref, runs its own `setup_host.py`, calls its `cli.py build`, then uploads the resulting image, checksums, and build log.

> Upstream: [`MysticGSI/mysticgsi`](https://github.com/MysticGSI/mysticgsi) (Apache-2.0). All conversion logic and credit belong there.

## What it does

1. Frees disk space on the runner.
2. Fetches MysticGSI at the ref you choose (`main` by default; pin a commit for reproducible builds).
3. Installs MysticGSI's host dependencies (`setup_host.py`: apt packages, `.venv`, pip requirements).
4. Runs `cli.py build <name> <firmware>` with your type/format/flags.
5. Collects `out/`, writes `SHA256SUMS` and `build-info.txt`, uploads an artifact, and optionally publishes a release.

## Supported firmware (via MysticGSI)

- Full OTA zips (`payload.bin`)
- Fastboot packages, including `.tgz` / `.tar.gz` archives
- `super.img` and sparse images
- `system.new.dat` ROM zips
- Samsung tars (`.tar.md5`)
- Huawei `UPDATE.APP`
- Unisoc `.pac`
- LG `.kdz`
- Oppo/Realme `.ozip`
- QFIL packages
- Sony `.sin`
- Pixel factory images

System partitions may be ext4, EROFS, or F2FS. ROM types include Pixel, Samsung One UI, Xiaomi MIUI/HyperOS, OPPO/Realme/OnePlus, Huawei/Honor, Nothing, ZTE, Lenovo, and generic/custom ROMs.

## Quick start

1. Push this repository to GitHub.
2. Go to **Actions → Build GSI from OEM firmware → Run workflow**.
3. Enter the build name and a **direct** firmware URL (Google Drive and other interstitial pages do not work; MysticGSI downloads with `aria2c`).
4. Pick a ROM type (`auto` usually works), filesystem, and options.
5. Download the raw `.img` from the run's `mystic-gsi-*-image` artifact. The release (when enabled) contains only metadata and checksums — GitHub caps release assets at 2 GB.

Example inputs:

| Field | Value |
| --- | --- |
| `name` | `raven` |
| `firmware` | `https://dl.google.com/dl/android/aosp/raven-up1a.231105.003-factory-76a795d5.zip` |
| `type` | `pixel` |
| `format` | `ext4` |
| `compress` | `false` |

## Inputs

| Input | Default | Passed to MysticGSI as |
| --- | --- | --- |
| `name` | `mystic` | build name (`out/<name>/`) |
| `firmware` | — | firmware path or URL |
| `type` | `auto` | `--type` |
| `type_override` | empty | `--type <type>:<override>` |
| `format` | `ext4` | `--format` for `lz4`/`lz4hc`/`lzma`; omitted for ext4 |
| `compress` | `false` | `--compress` (optional ZIP; off by default) |
| `no_debloat` | `false` | `--no-debloat` |
| `no_merge` | `false` | `--no-merge` (separate system/product images) |
| `add_tag` | empty | `--add` |
| `mystic_ref` | `main` | upstream branch, tag, or full commit SHA |
| `runner` | `ubuntu-24.04` | runner label |
| `upload_release` | `true` | publish a release |
| `retention_days` | `14` | artifact retention |

`type_override` produces `--type TYPE:OVERRIDE`, which MysticGSI uses to override auto-detection (meaningful with `auto`, `generic`, or `custom`).

## Outputs

MysticGSI writes to `out/<name>/`. The build run publishes **two artifacts**:

| Artifact | Contents |
| --- | --- |
| `mystic-gsi-<name>-<timestamp>-image` | Raw `.img` files only — no ZIP, no repackaging. |
| `mystic-gsi-<name>-<timestamp>-meta` | `build-info.txt`, `SHA256SUMS`, `build.log`, `gsilist.json`, `output.txt`. |

```
image artifact/
└── <rom>-<codename>-<android>-<incremental>-AB-<date>-MysticGSI.img

meta artifact/
├── build-info.txt       # upstream commit, firmware hash, flags, sizes
├── SHA256SUMS           # checksums of the .img files above
├── build.log
├── gsilist.json
└── output.txt
```

With `no_merge=true`, images get a `-separate` suffix and each partition (`system`, `product`, …) is built separately.

The release job attaches **only the small metadata files** and links back to the run. GitHub limits release assets to 2 GB, so the image is never uploaded as a release asset.

## Get the image from a run

Run **Actions → Get image from workflow run**, enter the source run ID (and optionally an artifact name), and the workflow will:

1. Find the `*-image` and `*-meta` artifacts in that run.
2. Download the raw `.img` unchanged (no ZIP, no recompression).
3. Verify it with that run's `SHA256SUMS`.
4. Re-upload it as `mystic-gsi-image-from-run-<run_id>` for downloading.

## AVB signing

By default MysticGSI signs with AOSP's test key. To sign with your own key, add a repository secret named **`MYSTIC_AVB_KEY`** containing either the PEM text or its base64 encoding. The workflow writes it to a temporary file and passes `--avb-key`; the key is never uploaded.

## Runner requirements

Conversion is much lighter than an AOSP build, but large firmware still needs room: the downloaded archive, extracted partitions, merged system tree, and the output image can peak at several times the firmware size.

| Runner | Notes |
| --- | --- |
| `ubuntu-24.04` (default) | Works for small/medium firmware after the disk-cleanup step; large HyperOS/One UI packages may run out of space. |
| Larger GitHub runner | Set `runner` to the larger-runner label. |
| Self-hosted | Recommended for big firmware; also required if `firmware` is a local path. |

The job times out after 6 hours. `ubuntu-24.04` is x86_64, matching MysticGSI's bundled Linux binaries.

## Reproducibility

`mystic_ref` defaults to `main`, so builds track upstream. For repeatable output, pass a full commit SHA. The resolved commit is recorded in `build-info.txt`, the release body, and the job summary.

## Local use

The wrapper scripts target Linux (or WSL). MysticGSI itself also supports macOS and Windows — see its README.

```bash
export MYSTIC_DIR="$PWD/mysticgsi"
export FIRMWARE=/path/to/firmware.zip
export BUILD_NAME=mystic
export TYPE=auto

bash scripts/fetch-mysticgsi.sh
bash scripts/setup-mysticgsi.sh     # uses sudo for apt packages
bash scripts/build-gsi.sh
bash scripts/collect-outputs.sh
```

Or skip the wrapper and use MysticGSI directly:

```bash
git clone https://github.com/MysticGSI/mysticgsi.git
cd mysticgsi
./setup_host.py
.venv/bin/python cli.py build mystic /path/to/firmware.zip --type auto
```

## Troubleshooting

- **`No space left on device`** — use a larger or self-hosted runner. The cleanup step frees several GB but cannot beat large firmware.
- **Download fails** — MysticGSI uses `aria2c` and needs a direct link; Google Drive/MEGA share pages are not supported. Host the file somewhere with a stable direct URL.
- **Corrupt `.tgz`** — the wrapper preflights local `.tgz`/`.tar.gz` files with `gzip -t` and `tar -tzf` and fails with a clear message before the slow setup steps. For URLs, the check happens inside MysticGSI after download. Extraction itself is always done by MysticGSI.
- **Signed firmware URLs** — `aria2c` prints the URL it downloads, so tokens can appear in `build.log`. The wrapper masks `token=`/`sig=`/`X-Amz-` URLs and strips query strings from summaries, but prefer a credential-free link.
- **Type detection failed** — set `type` explicitly (`oneui`, `hyperos`, `miui`, `pixel`, `coloros`, …), or use `type_override`.
- **`aria2c not found`** — `setup_host.py` installs it on Debian/Ubuntu; install `aria2` manually on custom runners.
- **Image does not boot** — GSI compatibility depends on the target device (Treble support, vendor, kernel, vbmeta). Try `ext4` instead of EROFS, and check MysticGSI's notes for your ROM type.
- **`--no-merge` image does not boot** — separate-partition images require a device that mounts `system`, `product`, and friends separately.
- **`Validation Failed: ReleaseAsset ... size must be less than 2147483648`** — a previous release tried to attach the image. Releases now carry metadata only; get the raw image from the run's `*-image` artifact or the **Get image from workflow run** workflow.
- **Artifact retention** — increase `retention_days`, or re-upload the image with **Get image from workflow run** to give it a fresh retention window.

See [docs/USAGE.md](docs/USAGE.md) for detailed recipes and internals.

## Credits and license

- Conversion: [MysticGSI](https://github.com/MysticGSI/mysticgsi), Apache-2.0. This repository downloads it at runtime and does not vendor its code or assets.
- Wrapper: MIT, see [LICENSE](LICENSE).

Flashing a GSI can brick a device or wipe data. Use firmware you are entitled to use, back up first, and know how to restore your device. No warranty.
