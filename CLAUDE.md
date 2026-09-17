# Style Rank

A Cyber Engine Tweaks mod for Cyberpunk 2077. Lua on LuaJIT (5.1 semantics),
loaded by CET at runtime. There is no test harness and no way to run it without
the game, so verification here is static analysis plus checksums.

## Before pushing

```sh
luacheck .
shellcheck scripts/update-deps.sh
./scripts/update-deps.sh --check
```

All three run in CI.

## cet-kit/ is vendored — never edit it by hand

Those files are copied from psiberx/cp2077-cet-kit, pinned by commit and
SHA-256 in `deps.lock`. `scripts/update-deps.sh --check` fails if they drift,
and CI runs it.

This rule exists because it was broken once: a local patch to `GameUI.lua` sat
unreviewed for years and contained a nil dereference. A fix belongs upstream,
then re-pin with `--upgrade`. Do not patch in place, even for one line.

## CET runtime constraints

- **Globals are shared across every installed CET mod.** Declare everything
  `local`. A bare assignment leaks into other people's mods.
- **`GetMod()` only resolves during `onInit` or later**, and returns nil if the
  dependency is absent. CPStyling is a hard dependency; guard it rather than
  indexing it, and gate the per-frame handlers on the result.
- **Observing `PlayerPuppet.OnHit` also catches NPCs**, because CET resolves it
  to the inherited `ScriptedPuppet::OnHit`. The scoring depends on this — `self`
  is not always the player.

## Compatibility status

Last verified against game patch 1.6. The game is now 2.x, which rewrote combat,
health and perks. **Do not describe this mod as working on 2.x.** Open questions
and what to check are in `docs/compatibility-2x.md`; `tools/style-rank-probe/`
answers them in game.

## Pushing workflow files

Changes under `.github/workflows/` need the GitHub `workflow` token scope.
Cloud sessions do not have it — both `git push` and the GitHub MCP tools fail
with "Insufficient scope". Leave those edits to a local checkout.
