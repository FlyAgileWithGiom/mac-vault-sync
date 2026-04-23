# Claude / agent instructions for this repo

## Release process — read before tagging

**See `RELEASE.md` for the full process.** Key rules:

- Git tags use **bare semver only, no `v` prefix** (e.g. `1.3.0`, not `v1.3.0`)
  - Obsidian's plugin updater matches the tag against `manifest.json.version`
    verbatim; a `v` prefix silently breaks updates
  - The `v`-prefixed convention used in other repos of this workspace (to
    trigger deployment pipelines) does **not** apply here
- Every release must have `main.js`, `manifest.json`, `styles.css` attached
  as binary assets
- `manifest.json.version`, `package.json.version`, and the git tag must all
  match exactly

## When asked to cut a release

Follow the checklist in `RELEASE.md`. Do not improvise naming. If unsure
whether to prefix `v`, the answer is: no.

## Known historical traps

- Past Claude sessions have created `v`-prefixed tags and releases without
  assets, leaving installs stuck. Don't repeat. Check the latest release's
  tag name before cutting a new one — if a `v`-prefixed release exists on
  this repo, something is already broken.
