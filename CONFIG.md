# RVCArise Configuration Reference

## config.toml

### Global Options

| Option | Default | Description |
|--------|---------|-------------|
| `enable-module-update` | `true` | Auto-update Magisk modules |
| `parallel-jobs` | `2` | Parallel build jobs |
| `compression-level` | `9` | Module zip compression |
| `riplib` | `true` | Use riplib instead of smali |
| `remove-rv-integrations-checks` | `true` | Skip GmsCore version checks |
| `continue-on-error` | `true` | Continue if one app fails |
| `default-arch` | `arm64-v8a` | Default architecture |

### Per-App Options

| Option | Description |
|--------|-------------|
| `enabled` | Build this app |
| `app-name` | App display name |
| `patches-source` | GitHub repo for patches |
| `patches-version` | `"latest"` or pinned tag |
| `cli-source` | GitHub repo for CLI |
| `rv-brand` | Brand name for output |
| `build-mode` | `"apk"`, `"both"` (APK + module), or `"module"` |
| `arch` | Target architecture |
| `included-patches` | Patches to include |
| `excluded-patches` | Patches to exclude |
| `patcher-args` | Extra args for patcher |
| `uptodown-dlurl` | Uptodown download URL |
| `apkmirror-dlurl` | APKMirror download URL |
