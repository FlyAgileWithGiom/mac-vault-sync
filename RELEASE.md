# Release Process

This plugin is installed via BRAT or manually from GitHub Releases. Obsidian's
plugin update mechanism matches the git tag **exactly** against
`manifest.json.version`, so tag naming is not cosmetic.

## Naming convention

- Git tag: bare semver, **no `v` prefix** (e.g. `1.3.0`, not `v1.3.0`)
- GitHub release title: same bare semver, optionally followed by a short summary
  (e.g. `1.3.0 - Memory fixes`)
- `manifest.json.version` must equal the tag
- `package.json.version` should track the same value (kept in sync manually)

A `v`-prefixed tag will not be recognised by BRAT / Obsidian's updater and
**will not trigger an update** for existing installs.

> `v`-prefixed tags are a convention used in other projects in this workspace
> (to trigger deployment pipelines). Do **not** carry that convention over
> here.

## Required release assets

Every release must have these three files attached as binary assets (not just
referenced from the source tree):

- `main.js` — built bundle (run `npm run build` first)
- `manifest.json` — must contain the same `version` as the tag
- `styles.css`

Missing any of these = plugin cannot be installed/updated.

## Steps

1. Bump `manifest.json.version` and `package.json.version` (same value)
2. Add an entry to `versions.json` mapping the new version to `minAppVersion`
3. `npm run build` to regenerate `main.js`
4. Commit: `chore: release X.Y.Z`
5. Tag: `git tag X.Y.Z && git push origin X.Y.Z` (no `v` prefix)
6. Create GitHub release on that tag, upload `main.js`, `manifest.json`,
   `styles.css` as assets
7. Verify: `curl -sL https://github.com/FlyAgileWithGiom/obsidian-vault-sync/releases/download/X.Y.Z/manifest.json` returns the new version

## Why this matters

A mismatched tag (e.g. `v1.3.0` while manifest says `1.3.0`) or a release with
missing assets leaves existing installs unable to update. The symptom is
silent — Obsidian simply doesn't show the new version. Debugging this
retroactively is painful because the release looks fine in the GitHub UI.
