# Releasing a New Version

How to cut a new release of Inboxed.

---

## Versioning

Inboxed follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (`X.0.0`) — breaking API or config changes
- **MINOR** (`0.X.0`) — new features, backward-compatible
- **PATCH** (`0.0.X`) — bug fixes only

---

## Release Checklist

### 1. Update version numbers

Bump the version in all packages:

```bash
# Dashboard
# apps/dashboard/package.json → "version": "X.Y.Z"

# MCP server
# apps/mcp/package.json → "version": "X.Y.Z"
```

### 2. Update CHANGELOG.md

Move items from `[Unreleased]` into a new version section:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

### 3. Commit the version bump

```bash
git add -A
git commit -m "release: v0.X.Y"
```

### 4. Create and push the tag

```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin master --tags
```

### 5. Create GitHub Release

```bash
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes-from-tag
```

Or use `--generate-notes` to auto-generate from commits:

```bash
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --generate-notes
```

### 6. Deploy to production

Merge or push to the `production` branch to trigger the deploy workflow:

```bash
git checkout production
git merge master
git push origin production
```

The GitHub Actions workflow (`.github/workflows/deploy.yml`) will:
1. Build all 3 Docker images (API, Dashboard, MCP)
2. Push to ghcr.io
3. Deploy via Kamal to the VPS

---

## Hotfix Releases

For urgent fixes on production:

```bash
# Branch from the production tag
git checkout -b hotfix/vX.Y.Z vX.Y.Z

# Make fixes, then:
git commit -m "fix: description"

# Bump patch version, update changelog
git commit -m "release: vX.Y.Z+1"
git tag -a vX.Y.Z+1 -m "vX.Y.Z+1"

# Merge back
git checkout production && git merge hotfix/vX.Y.Z
git push origin production --tags

git checkout master && git merge hotfix/vX.Y.Z
git push origin master
```

---

## Docker Image Tags

Each release produces these images:

| Image | Tags |
|-------|------|
| `ghcr.io/<owner>/inboxed-api` | `latest`, `vX.Y.Z`, `<sha>` |
| `ghcr.io/<owner>/inboxed-dashboard` | `latest`, `vX.Y.Z`, `<sha>` |
| `ghcr.io/<owner>/inboxed-mcp` | `latest`, `vX.Y.Z`, `<sha>` |

The `docker.yml` workflow builds on push to `master` (dev images).
The `deploy.yml` workflow builds and deploys on push to `production`.

---

## Verify Release

After deploying:

```bash
# API health
curl https://inboxed.example.com/up

# SMTP connectivity
nc -z smtp.inboxed.example.com 2525

# Check running version on VPS
kamal app details
```
