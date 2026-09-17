# Workflows waiting to be installed

These two files belong in `.github/workflows/`. They are parked here because
the session that wrote them could not push to `.github/workflows/` — creating
or updating a workflow needs the GitHub `workflow` token scope, which neither
the OAuth token nor the GitHub App had.

Move them into place from a local checkout with a token that has the scope
(a normal `git push` from your own machine will do):

```sh
git mv docs/ci/ci.yml          .github/workflows/ci.yml
git mv docs/ci/update-deps.yml .github/workflows/update-deps.yml
git rm docs/ci/README.md
git commit -m "Install CI and dependency update workflows"
git push
```

## What they do

`ci.yml` — on every push and pull request:

- `luacheck init.lua`
- `shellcheck scripts/update-deps.sh`
- `./scripts/update-deps.sh --check`, so a hand-edit under `cet-kit/` fails the
  build instead of sitting unreviewed

`update-deps.yml` — Mondays at 06:00 UTC, and on demand: re-pins `deps.lock` to
upstream HEAD and opens a pull request if anything changed.

`update-deps.yml` needs **Allow GitHub Actions to create and approve pull
requests** enabled under Settings → Actions → General. Without it the workflow
runs and then fails at the `gh pr create` step.

Both were validated before being parked: the YAML parses, and the shell in the
`update-deps.yml` run block is shellcheck-clean.
