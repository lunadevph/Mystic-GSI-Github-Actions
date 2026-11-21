# Patches

Optional patches applied by `scripts/20-build.sh` before the build starts.

Layout: one directory per Android project, named after the project path with `/` replaced by `_`.

```
patches/
├── frameworks_base/
│   └── 0001-mystic-branding.patch
└── packages_apps_Settings/
    └── 0001-hide-oem-unlock-warning.patch
```

Each patch is applied with:

```bash
git -C source/<project path> apply <patch>
```

Create one from an existing change:

```bash
git -C source/frameworks/base format-patch -1 --stdout > patches/frameworks_base/0001-mystic-branding.patch
```

Patches for projects missing from the current manifest are skipped with a warning, so the same patch set can be reused across manifests.
