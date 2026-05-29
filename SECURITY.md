# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not** open a public issue.

Instead, report it privately via GitHub Security Advisories:
1. Go to [Security Advisories](https://github.com/Chrispsz/rvcbotbuilds/security/advisories)
2. Click "Report a vulnerability"
3. Provide details about the vulnerability

## Secrets

This project uses GitHub Secrets for sensitive data:

| Secret | Purpose | Scope |
|--------|---------|-------|
| `PAT_TOKEN` | Push to Chrispsz/piko fork | Fine-grained PAT with `contents: write` on `Chrispsz/piko` only |
| `KS_KEYSTORE_B64` | Base64-encoded keystore for APK signing | Repo secret |
| `KS_P12_KEYSTORE_B64` | Base64-encoded P12 keystore | Repo secret |
| `GITHUB_TOKEN` | Auto-provided by Actions | Job-scoped, ephemeral |

### Minimum PAT_TOKEN scopes (fine-grained):
- Repository: `Chrispsz/piko`
- Permissions: Contents (read/write)

**Never hardcode secrets in source files.**

## APK Signing

APKs are signed during CI with keystores restored from base64 secrets.
The signing passwords are in `utils.sh` (inherited from upstream j-hc).
Build logs redact passwords via sed before printing.

## OTA Security

- OTA downloads APKs from GitHub Releases over HTTPS
- Downloaded APKs are verified against the installed app's signature before install
- Signature mismatch shows a warning dialog instead of auto-installing
- 24h cooldown prevents excessive API calls
- No root required for OTA updates

## Overlay System

Custom Java files in `overlay/` are applied to the piko fork during CI via `apply-overlay.sh`.
These files override specific classes in the piko patches source tree.
All overlay files are version-controlled and auditable.

If a secret is accidentally committed:
1. Revoke the secret immediately
2. Rotate all affected credentials
3. Use `git filter-repo` to remove from history if needed
