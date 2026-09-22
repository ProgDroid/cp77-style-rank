---
name: vendored-patch-discarded-2026-09-22
description: The local hand-patch to cet-kit/GameUI.lua was discarded on 2026-09-22 because upstream v1.2.3 already contains it — do not resurrect it
metadata:
  type: project
---

An uncommitted local patch to `cet-kit/GameUI.lua` sat in the working tree for a
long time. It was not junk: it fixed a real nil dereference
(`request.pointData.pointRecord` → `request.pointData and … or nil`) and removed
the `request = _` argument-shift shims. It was discarded on 2026-09-22.

**Why:** the vendored kit was re-pinned to upstream **v1.2.3** (framework
1.29.0, `psiberx/cp2077-cet-kit` at `f64c837e589f`), which contains that exact
guard byte-for-byte and has already dropped the shims. The local patch was a
hand-applied backport of a fix that now arrives from upstream. Keeping it would
also fail the `deps` CI job, since `deps.lock` hashes those files.

**How to apply:** if you find a copy of this patch in a backup, a stash, or an
old clone, do not reapply it — check the current vendored version first. The
same reasoning covers any future cet-kit fix: it goes upstream, then the kit is
re-pinned with `./scripts/update-deps.sh --upgrade`. Never patch in place.

Do not confuse this with a checksum failure on a fresh Windows clone, which is a
different problem entirely — see [[line-ending-gate-recipe]].
