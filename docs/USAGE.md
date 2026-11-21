# Usage details

This repository drives [MysticGSI](https://github.com/MysticGSI/mysticgsi) from GitHub Actions. It contains no converter code: every build runs upstream's `cli.py`.

## How a run is assembled

| Workflow step | Script | What it does |
| --- | --- | --- |
| Free disk space | `scripts/free-disk.sh` | Removes unused preinstalled toolchains on GitHub-hosted runners. |
| Fetch MysticGSI | `scripts/fetch-mysticgsi.sh` | Shallow-fetches `MYSTIC_REF` into `mysticgsi/` and records the commit. |
| Set up MysticGSI | `scripts/setup-mysticgsi.sh` | Runs upstream `setup_host.py` (apt packages, `.venv`, requirements). |
| Prepare AVB key | inline | Decodes `MYSTIC_AVB_KEY` (PEM or base64) into a temp file when the secret exists. |
| Build GSI | `scripts/build-gsi.sh` | Maps inputs to `cli.py build` flags and tees the log. |
| Collect outputs | `scripts/collect-outputs.sh` | Copies `out/`, writes `SHA256SUMS` and `build-info.txt`. |

## Input mapping

| Input | MysticGSI flag | Notes |
| --- | --- | --- |
| `name` | positional `name` | Must match `[A-Za-z0-9._-]{1,64}`; MysticGSI validates this too. |
| `firmware` | positional `source` | URL or local path. Direct links only for URLs. |
| `type` | `--type` | `auto` detects from properties. |
| `type_override` | `--type TYPE:OVERRIDE` | Overrides detection for `auto`/`generic`/`custom`. |
| `format=ext4` | *(no flag)* | Default ext4 image. |
| `format=lz4/lz4hc/lzma` | `--format` | Builds EROFS instead. |
| `compress=true` | `--compress` | Adds a ZIP containing `<partition>.img` files. |
| `no_debloat=true` | `--no-debloat` | Keeps apps the patch set would remove. |
| `no_merge=true` | `--no-merge` | Separate partition images instead of merging into `system`. |
| `add_tag` | `--add` | Appended to the display name. |
| `MYSTIC_AVB_KEY` | `--avb-key` | PEM or base64 in a repository secret. |

## Recipes

### Pixel factory image

```yaml
name: raven
firmware: https://dl.google.com/dl/android/aosp/raven-up1a.231105.003-factory-76a795d5.zip
type: pixel
format: ext4
```

### Samsung One UI tar

Host the `AP_*.tar.md5` (or the full multi-file tar) at a direct URL, then:

```yaml
type: oneui
format: ext4
compress: true
```

### Xiaomi HyperOS / MIUI

```yaml
type: hyperos   # or miui
format: ext4
```

### Custom ROM zip (system.new.dat)

```yaml
type: generic
```

If auto-detection picks the wrong vendor, try `type_override` with the ROM's prop family (for example `lineageOS`).

### EROFS output

```yaml
format: lz4hc
```

The target kernel and `fstab` must support EROFS; `lzma` additionally needs `CONFIG_EROFS_FS_ZIP_LZMA`.

### Separate partitions

```yaml
no_merge: true
```

Produces `*-system.img`, `*-product.img`, and other partition images. Only for devices that mount those partitions separately.

## Artifacts and releases

Artifacts contain `out/` plus metadata:

```
<name>/<output>.img
<name>/<output>.img.zip   # if compress=true
<name>/output.txt
build.log
gsilist.json
SHA256SUMS
build-info.txt
```

When `upload_release=true`, the same files are attached to a release tagged `mystic-gsi-<name>-<UTC timestamp>`. Release bodies record the resolved MysticGSI commit.

`build-info.txt` includes:

- upstream commit and requested ref
- build name, ROM type, format, and flags
- firmware file name, size, and SHA-256 (when the archive is retained)
- SHA-256 for every produced image/ZIP

## Pinning MysticGSI

`mystic_ref` accepts a branch, tag, or full commit SHA:

```yaml
mystic_ref: 4f3c2b1a9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a
```

GitHub allows fetching reachable commits by SHA, so a pinned commit works with the shallow fetch. Short SHAs are not supported by `git fetch`; use the full 40-character SHA.

## Disk and time budget

A build peak includes:

1. the firmware archive (often 2–10 GB),
2. extracted partition images (roughly firmware size),
3. unpacked filesystem trees (roughly partition size),
4. the output image and optional ZIP.

`ubuntu-latest` starts with ~14 GB free; the cleanup step raises this to roughly 35–45 GB. Small and medium firmware fits; very large dynamic-partition packages may not. Use a larger runner or self-hosted machine for those, and disable `compress` to avoid keeping both raw and ZIP outputs.

## Debugging a failed run

1. Check the **`<artifact>-logs`** artifact, which is uploaded when the build fails and contains `build.log`. On success the same log is inside the main artifact.
2. Confirm the firmware URL is direct and reachable.
3. Re-run with an explicit `type`.
4. Check free space in the **Free disk space** step output.
5. Try `format: ext4` if an EROFS image does not boot.

## Differences from upstream

The wrapper only adds: disk cleanup, ref pinning, input validation, checksums, build metadata, artifact/release upload, and secret-based AVB signing. It does not modify MysticGSI or apply extra patches.
