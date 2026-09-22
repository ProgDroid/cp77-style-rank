---
name: line-ending-gate-recipe
description: If update-deps.sh --check fails on Windows it is line endings, not drift — and the fix is a forced re-checkout, not git add --renormalize
metadata:
  type: project
---

`./scripts/update-deps.sh --check` compares SHA-256 of `cet-kit/*` against the
bytes upstream published. On a Windows checkout with `core.autocrlf=true` the
files arrive CRLF, so every one of them reports drift while being untouched, and
the script aborts even earlier — `read` leaves a stray `\r` on the blank line of
`deps.lock` and it dies with `unrecognised key ''`. CI runs on ubuntu-latest,
where the checkout is already LF, so none of this is visible there.

`.gitattributes` now pins `eol=lf` globally and marks `cet-kit/** -text`.

**Why:** the failure looks exactly like someone hand-edited the vendored kit,
which is the one thing [[vendored-patch-discarded-2026-09-22]] says never to do.
Reaching for `--upgrade` or re-vendoring to "fix" it would be chasing a bug that
does not exist.

**How to apply:** confirm the diagnosis before acting — `tr -cd '\r' < cet-kit/GameUI.lua | wc -c`
should be 0, and `tr -d '\r' < cet-kit/GameUI.lua | sha256sum` should equal the
value in `deps.lock`. If it does, the bytes are fine and only the checkout is wrong.

To repair the working tree, use a forced re-checkout:

```sh
git rm --cached -r . -q && git reset --hard
```

**Do not use `git add --renormalize .`** — `cet-kit/** -text` means "store bytes
verbatim", so renormalize stages the CRLF working copy *into* the index and
permanently breaks the checksums. Measured 2026-09-22: it staged 1276 CRs into
`GameUI.lua`. Also note `git status` will call the tree clean while `deps.lock`
still has CRs, because `text=auto` normalises both forms to the same blob.
