# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not** open a public issue.

Instead, report it privately via GitHub Security Advisories:
1. Go to [Security Advisories](https://github.com/Chrispsz/rvcbotbuilds/security/advisories)
2. Click "Report a vulnerability"
3. Provide details about the vulnerability

## Secrets

This project uses environment variables for sensitive data:
- `BOT_TOKEN` — Telegram Bot Token (stored in `bot/.env`, never committed)
- `ADMIN_ID` — Telegram Admin ID (stored in `bot/.env`, never committed)
- GitHub PAT — Used only in CI/CD via GitHub Secrets

**Never hardcode secrets in source files.** Use `.env` files (excluded via `.gitignore`) or GitHub Secrets.

If a secret is accidentally committed:
1. Revoke the secret immediately
2. Rotate all affected credentials
3. Use `git filter-repo` to remove from history if needed
